import { Webhook } from "npm:standardwebhooks@1.1.1";
import type { PublishCommandInput } from "npm:@aws-sdk/client-sns@3.1144.0";
import { createSendSmsHandler } from "./index.ts";

const hookSecretBytes = "Kaysons Auth Hook Test Secret 32 bytes";
const hookSecretBase64 = btoa(hookSecretBytes);
const hookSecret = `v1,whsec_${hookSecretBase64}`;
const smsBodyTemplate =
  "Your Kaysons verification code is {{otp}}. Valid for 5 minutes.";

function assertEquals<T>(actual: T, expected: T, message: string) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `${message}: expected ${JSON.stringify(expected)}, got ${
        JSON.stringify(actual)
      }`,
    );
  }
}

function environment(overrides: Record<string, string | undefined> = {}) {
  const values: Record<string, string | undefined> = {
    SEND_SMS_HOOK_SECRETS: hookSecret,
    AWS_REGION: "us-east-1",
    AWS_ACCESS_KEY_ID: "test-access-key",
    AWS_SECRET_ACCESS_KEY: "test-secret-key",
    AWS_SMS_ROUTE: "india-international",
    AWS_SMS_MAX_PRICE_USD: "0.10",
    OTP_SMS_BODY_TEMPLATE: smsBodyTemplate,
    ...overrides,
  };
  return (name: string) => values[name];
}

function signedRequest(
  body: Record<string, unknown>,
  overrides: Record<string, string> = {},
) {
  const rawBody = JSON.stringify(body);
  const id = crypto.randomUUID();
  const timestamp = new Date();
  const signature = new Webhook(hookSecretBase64).sign(id, timestamp, rawBody);
  return new Request("https://hook.test/send-sms-otp", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "webhook-id": id,
      "webhook-timestamp": String(Math.floor(timestamp.getTime() / 1000)),
      "webhook-signature": signature,
      ...overrides,
    },
    body: rawBody,
  });
}

function payload(phone = "+919876543210", otp = "123456") {
  return { user: { phone }, sms: { otp } };
}

Deno.test("rejects absent and invalid signatures without calling AWS", async () => {
  let awsCalls = 0;
  const handler = createSendSmsHandler({
    getEnv: environment(),
    sendSms: async () => {
      awsCalls += 1;
    },
  });

  const absentSignature = await handler(
    new Request(
      "https://hook.test/send-sms-otp",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload()),
      },
    ),
  );
  assertEquals(absentSignature.status, 401, "missing signature status");

  const invalidSignature = await handler(
    signedRequest(payload(), { "webhook-signature": "v1,invalid" }),
  );
  assertEquals(invalidSignature.status, 401, "invalid signature status");
  assertEquals(awsCalls, 0, "AWS calls for unsigned requests");
});

Deno.test("signed India international payload canonicalizes phone formats and publishes cost-capped fields", async () => {
  const awsCalls: PublishCommandInput[] = [];
  const handler = createSendSmsHandler({
    getEnv: environment(),
    sendSms: async (_config, input) => {
      awsCalls.push(input);
    },
  });

  for (const inputPhone of ["+919876543210", "919876543210"]) {
    const response = await handler(signedRequest(payload(inputPhone)));
    assertEquals(response.status, 200, "valid signed request status");
  }
  assertEquals(awsCalls.length, 2, "AWS call count");
  assertEquals(awsCalls[0].PhoneNumber, "+919876543210", "E.164 destination");
  assertEquals(
    awsCalls[1].PhoneNumber,
    "+919876543210",
    "normalized destination",
  );
  assertEquals(awsCalls[0].Message, awsCalls[1].Message, "same rendered SMS");
  assertEquals(
    awsCalls[0].Message,
    "Your Kaysons verification code is 123456. Valid for 5 minutes.",
    "OTP template substitution",
  );
  assertEquals(
    awsCalls[0].MessageAttributes,
    {
      "AWS.SNS.SMS.SMSType": {
        DataType: "String",
        StringValue: "Transactional",
      },
      "AWS.SNS.SMS.MaxPrice": { DataType: "String", StringValue: "0.1000" },
    },
    "international route attributes",
  );
});

Deno.test("signed India local payload includes registered sender and DLT IDs", async () => {
  const awsCalls: PublishCommandInput[] = [];
  const handler = createSendSmsHandler({
    getEnv: environment({
      AWS_REGION: "ap-south-1",
      AWS_SMS_ROUTE: "india-local",
      AWS_SMS_SENDER_ID: "KAYSON",
      AWS_SMS_DLT_ENTITY_ID: "PE12345678901234567890",
      AWS_SMS_DLT_TEMPLATE_ID: "1107161234567890123",
    }),
    sendSms: async (_config, input) => {
      awsCalls.push(input);
    },
  });

  const response = await handler(signedRequest(payload()));
  assertEquals(response.status, 200, "valid signed local request status");
  assertEquals(awsCalls.length, 1, "AWS call count");
  assertEquals(
    awsCalls[0].MessageAttributes,
    {
      "AWS.SNS.SMS.SMSType": {
        DataType: "String",
        StringValue: "Transactional",
      },
      "AWS.SNS.SMS.MaxPrice": { DataType: "String", StringValue: "0.1000" },
      "AWS.SNS.SMS.SenderID": { DataType: "String", StringValue: "KAYSON" },
      "AWS.MM.SMS.EntityId": {
        DataType: "String",
        StringValue: "PE12345678901234567890",
      },
      "AWS.MM.SMS.TemplateId": {
        DataType: "String",
        StringValue: "1107161234567890123",
      },
    },
    "local route attributes",
  );
});

Deno.test("rejects invalid Indian destinations and incomplete local config without AWS calls", async () => {
  let awsCalls = 0;
  const validConfig = environment();
  const handler = createSendSmsHandler({
    getEnv: validConfig,
    sendSms: async () => {
      awsCalls += 1;
    },
  });
  const invalidDestination = await handler(
    signedRequest(payload("+14155550123")),
  );
  assertEquals(invalidDestination.status, 400, "non-India destination status");

  const incompleteLocalConfig = createSendSmsHandler({
    getEnv: environment({ AWS_SMS_ROUTE: "india-local" }),
    sendSms: async () => {
      awsCalls += 1;
    },
  });
  const incompleteConfigResponse = await incompleteLocalConfig(
    signedRequest(payload()),
  );
  assertEquals(
    incompleteConfigResponse.status,
    503,
    "incomplete DLT config status",
  );
  assertEquals(awsCalls, 0, "AWS calls for invalid destination/config");
});
