import {
  PublishCommand,
  type PublishCommandInput,
  SNSClient,
} from "npm:@aws-sdk/client-sns@3.1144.0";
import { FetchHttpHandler } from "npm:@smithy/fetch-http-handler@5.8.0";
import { Webhook } from "npm:standardwebhooks@1.1.1";

const MAX_HOOK_BYTES = 20 * 1024;
const AWS_REQUEST_TIMEOUT_MS = 2_200;
const AWS_SMS_MAX_PRICE_HARD_CAP_USD = 1;

type AuthHookPayload = {
  user?: { phone?: unknown };
  sms?: { otp?: unknown };
};

type EnvReader = (name: string) => string | undefined;
type SmsConfiguration = NonNullable<ReturnType<typeof getSmsConfiguration>>;

type HandlerDependencies = {
  getEnv: EnvReader;
  sendSms: (
    config: SmsConfiguration,
    input: PublishCommandInput,
  ) => Promise<void>;
};

function json(body: Record<string, unknown>, status = 200, retryable = false) {
  const headers = new Headers({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  if (retryable) headers.set("Retry-After", "true");
  return new Response(JSON.stringify(body), { status, headers });
}

function configuredHookSecrets(getEnv: EnvReader): string[] {
  const configured = getEnv("SEND_SMS_HOOK_SECRETS") ?? "";
  return configured.split("|").map((entry) => entry.trim()).filter(Boolean);
}

function hasUsableHookSecret(getEnv: EnvReader): boolean {
  return configuredHookSecrets(getEnv).some((secret) =>
    /^v1,whsec_[A-Za-z0-9+/]+={0,2}$/.test(secret)
  );
}

function verifyHook(
  payload: string,
  headers: Headers,
  secrets: string[],
): AuthHookPayload | null {
  if (!secrets.length) return null;

  // Supabase supplies Standard Webhooks secrets as `v1,whsec_<base64>`.
  // Support `|` separated values during rotation, as documented by Supabase.
  for (const secret of secrets) {
    if (!secret.startsWith("v1,whsec_")) continue;
    try {
      const webhook = new Webhook(secret.slice("v1,whsec_".length));
      return webhook.verify(
        payload,
        Object.fromEntries(headers),
      ) as AuthHookPayload;
    } catch {
      // Try the next active rotation secret. Never log a signed payload or OTP.
    }
  }
  return null;
}

async function readBoundedBody(req: Request): Promise<string | null> {
  const declaredLength = Number(req.headers.get("content-length") ?? "0");
  if (declaredLength > MAX_HOOK_BYTES || !req.body) return null;

  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_HOOK_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
  } catch {
    return null;
  }

  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return null;
  }
}

function getSmsConfiguration(getEnv: EnvReader) {
  const region = getEnv("AWS_REGION")?.trim();
  const accessKeyId = getEnv("AWS_ACCESS_KEY_ID")?.trim();
  const secretAccessKey = getEnv("AWS_SECRET_ACCESS_KEY")?.trim();
  const sessionToken = getEnv("AWS_SESSION_TOKEN")?.trim();
  const route = getEnv("AWS_SMS_ROUTE")?.trim();
  const maxPrice = Number(getEnv("AWS_SMS_MAX_PRICE_USD"));
  const bodyTemplate = getEnv("OTP_SMS_BODY_TEMPLATE") ?? "";

  if (
    !region || !accessKeyId || !secretAccessKey ||
    !["india-international", "india-local"].includes(route ?? "") ||
    !Number.isFinite(maxPrice) || maxPrice <= 0 ||
    maxPrice > AWS_SMS_MAX_PRICE_HARD_CAP_USD ||
    bodyTemplate.length > 500 ||
    (bodyTemplate.match(/\{\{otp\}\}/g) ?? []).length !== 1
  ) {
    return null;
  }

  const senderId = getEnv("AWS_SMS_SENDER_ID")?.trim();
  const entityId = getEnv("AWS_SMS_DLT_ENTITY_ID")?.trim();
  const templateId = getEnv("AWS_SMS_DLT_TEMPLATE_ID")?.trim();
  if (
    route === "india-local" &&
    (!senderId || !entityId || !templateId ||
      !/^[A-Za-z]{3,6}$/.test(senderId) ||
      !["ap-south-1", "ap-south-2"].includes(region))
  ) {
    return null;
  }

  return {
    region,
    accessKeyId,
    secretAccessKey,
    sessionToken,
    route: route as "india-international" | "india-local",
    maxPrice: maxPrice.toFixed(4),
    bodyTemplate,
    senderId,
    entityId,
    templateId,
  };
}

function isTransientAwsFailure(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const candidate = error as {
    name?: unknown;
    $metadata?: { httpStatusCode?: unknown };
  };
  const status = Number(candidate.$metadata?.httpStatusCode ?? 0);
  const name = String(candidate.name ?? "");
  return status === 429 || status >= 500 || [
    "AbortError",
    "TimeoutError",
    "RequestTimeout",
    "ThrottlingException",
    "ServiceUnavailable",
    "InternalError",
  ].includes(name);
}

function normalizeIndianPhone(value: unknown): string | null {
  if (typeof value !== "string" || !/^\+?91[6-9][0-9]{9}$/.test(value)) {
    return null;
  }
  return value.startsWith("+") ? value : `+${value}`;
}

export function createSendSmsHandler({ getEnv, sendSms }: HandlerDependencies) {
  return async (req: Request): Promise<Response> => {
    const requestStartedAt = performance.now();
    if (req.method !== "POST") {
      return json({ error: "Method not allowed." }, 405);
    }
    if (
      !(req.headers.get("content-type") ?? "").toLowerCase().includes(
        "application/json",
      )
    ) {
      return json({ error: "Expected a JSON request." }, 415);
    }

    const rawPayload = await readBoundedBody(req);
    if (rawPayload === null) {
      return json({ error: "Invalid request body." }, 400);
    }

    const secrets = configuredHookSecrets(getEnv);
    const payload = verifyHook(rawPayload, req.headers, secrets);
    if (!payload) {
      console.info(JSON.stringify({
        event: "otp_hook_rejected_signature",
        duration_ms: Math.round(performance.now() - requestStartedAt),
      }));
      // Keep secret misconfiguration retryable; invalid signatures are rejected.
      if (!hasUsableHookSecret(getEnv)) {
        return json(
          { error: "SMS delivery is temporarily unavailable." },
          503,
          true,
        );
      }
      return json({ error: "Invalid hook signature." }, 401);
    }

    const phone = normalizeIndianPhone(payload.user?.phone);
    const otp = typeof payload.sms?.otp === "string" ? payload.sms.otp : "";
    if (!phone || !/^\d{6}$/.test(otp)) {
      return json({ error: "Invalid SMS destination or code." }, 400);
    }

    const config = getSmsConfiguration(getEnv);
    if (!config) {
      return json(
        { error: "SMS delivery is temporarily unavailable." },
        503,
        true,
      );
    }

    const messageAttributes: Record<
      string,
      { DataType: string; StringValue: string }
    > = {
      "AWS.SNS.SMS.SMSType": {
        DataType: "String",
        StringValue: "Transactional",
      },
      "AWS.SNS.SMS.MaxPrice": {
        DataType: "String",
        StringValue: config.maxPrice,
      },
    };
    if (config.route === "india-local") {
      messageAttributes["AWS.SNS.SMS.SenderID"] = {
        DataType: "String",
        StringValue: config.senderId!,
      };
      messageAttributes["AWS.MM.SMS.EntityId"] = {
        DataType: "String",
        StringValue: config.entityId!,
      };
      messageAttributes["AWS.MM.SMS.TemplateId"] = {
        DataType: "String",
        StringValue: config.templateId!,
      };
    }

    const awsStartedAt = performance.now();
    console.info(JSON.stringify({
      event: "otp_hook_send_started",
      route: config.route,
      region: config.region,
      pre_send_ms: Math.round(awsStartedAt - requestStartedAt),
    }));
    try {
      await sendSms(config, {
        PhoneNumber: phone,
        Message: config.bodyTemplate.replace("{{otp}}", otp),
        MessageAttributes: messageAttributes,
      });
      console.info(JSON.stringify({
        event: "otp_hook_send_succeeded",
        route: config.route,
        region: config.region,
        aws_ms: Math.round(performance.now() - awsStartedAt),
        total_ms: Math.round(performance.now() - requestStartedAt),
      }));
      return json({});
    } catch (error) {
      // Auth's HTTP hook budget is five seconds. Bound this call and let Auth
      // retry transient provider failures using its documented retry behavior.
      const transient = isTransientAwsFailure(error);
      const metadata = error && typeof error === "object"
        ? error as { name?: unknown; $metadata?: { httpStatusCode?: unknown } }
        : {};
      console.warn(JSON.stringify({
        event: "otp_hook_send_failed",
        route: config.route,
        region: config.region,
        aws_ms: Math.round(performance.now() - awsStartedAt),
        total_ms: Math.round(performance.now() - requestStartedAt),
        provider_error: String(metadata.name ?? "unknown").slice(0, 80),
        provider_status: Number(metadata.$metadata?.httpStatusCode ?? 0) ||
          null,
        retryable: transient,
      }));
      return transient
        ? json({ error: "SMS provider is temporarily unavailable." }, 503, true)
        : json({ error: "SMS provider rejected the request." }, 500);
    }
  };
}

if (import.meta.main) {
  let client: SNSClient | null = null;
  Deno.serve(createSendSmsHandler({
    getEnv: (name) => Deno.env.get(name),
    sendSms: async (config, input) => {
      if (!client) {
        client = new SNSClient({
          region: config.region,
          credentials: {
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey,
            ...(config.sessionToken
              ? { sessionToken: config.sessionToken }
              : {}),
          },
          maxAttempts: 1,
          requestHandler: new FetchHttpHandler({
            requestTimeout: AWS_REQUEST_TIMEOUT_MS,
          }),
        });
      }
      await client.send(new PublishCommand(input));
    },
  }));
}
