import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Json = Record<string, unknown>;
type Client = ReturnType<typeof createClient<any, "public", any>>;

const MODEL = "gpt-5.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-clawd-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const systemInstructions = [
  "You are Clawd, the operations analyst for Kaysons Logistics.",
  "Use only the computed logistics snapshot and ranked risk signals provided to you.",
  "Write for a non-technical logistics owner in concise markdown.",
  "When using a markdown table, put the header, separator, and every data row on separate lines, with a blank line before and after the table.",
  "Never expose database, SQL, API, JSON, UUID, table, column, schema, function, or implementation details.",
  "Translate risk signals into business language: missing POD, late acknowledgement, duplicate e-way bill, route cost spike, extra charge risk, or payment review.",
  "Do not accuse anyone of fraud as fact. Say risk, possible issue, or needs review unless the facts are conclusive.",
  "Do not say payment is blocked, held, or cannot be cleared. Say manual review before payment release is recommended.",
  "If someone asks whether payment is blocked, answer: No automatic payment stop is applied in v1, but manual review before release is recommended for risky shipments.",
].join("\n");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !openAiKey) {
    return json(
      {
        error:
          "Clawd is not fully configured. Set Supabase and OpenAI secrets.",
      },
      500,
    );
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const auth = await authenticate(req, supabaseUrl, anonKey);
  if (!auth.ok) return json({ error: auth.error }, auth.status);

  const body = await safeJson(req);
  const action = String(body.action ?? "chat");

  try {
    if (action === "detect_anomalies") {
      return json(await detectAnomalies(adminClient, auth.userId));
    }
    if (action === "daily_report" || action === "monthly_report") {
      return json(
        await generateReport({
          adminClient,
          openAiKey,
          userId: auth.userId,
          reportType: action === "monthly_report" ? "monthly" : "daily",
          force: body.force === true,
        }),
      );
    }
    if (action === "template_run") {
      return json(
        await runTemplate({
          adminClient,
          openAiKey,
          userId: auth.userId,
          templateId: String(body.template_id ?? ""),
          variables: asRecord(body.variables),
        }),
      );
    }

    const question = String(body.question ?? "").trim();
    if (!question) return json({ error: "Ask Clawd a question first." }, 400);
    return json(
      await chat({ adminClient, openAiKey, userId: auth.userId, question }),
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    try {
      await storeRun(adminClient, {
        run_type: action,
        prompt_text: "",
        model: MODEL,
        output_text: "",
        structured_output: {},
        input_snapshot: {},
        usage: {},
        status: "failed",
        error: message,
        requested_by: auth.userId,
      });
    } catch (_) {
      // Keep the client error useful even if audit storage is unavailable.
    }
    return json({ error: message }, 500);
  }
});

async function authenticate(
  req: Request,
  supabaseUrl: string,
  anonKey: string,
) {
  const cronSecret = Deno.env.get("CLAWD_CRON_SECRET") ?? "";
  const providedCronSecret = req.headers.get("x-clawd-cron-secret") ?? "";
  if (cronSecret && providedCronSecret && cronSecret === providedCronSecret) {
    return { ok: true as const, userId: null };
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) {
    return { ok: false as const, status: 401, error: "Missing staff session" };
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(
    token,
  );
  if (userError || !userData.user) {
    return { ok: false as const, status: 401, error: "Invalid session" };
  }

  const { data: profile, error: profileError } = await userClient
    .from("profiles")
    .select("id, role")
    .eq("id", userData.user.id)
    .maybeSingle();
  const role = String(profile?.role ?? "");
  if (
    profileError || !["admin", "accountant", "logistics_manager"].includes(role)
  ) {
    return {
      ok: false as const,
      status: 403,
      error:
        "Clawd is available to admins, accountants, and logistics managers only",
    };
  }
  return { ok: true as const, userId: userData.user.id };
}

async function chat(args: {
  adminClient: Client;
  openAiKey: string;
  userId: string | null;
  question: string;
}) {
  const facts = await loadFacts(args.adminClient, 80);
  const ai = await askOpenAI(
    args.openAiKey,
    [
      "Answer the staff question using the computed logistics facts.",
      "If facts are insufficient, say what business detail is needed.",
      "For payment-sensitive risks, recommend manual review before payment release.",
      `Question: ${args.question}`,
      `Computed facts:\n${JSON.stringify(facts)}`,
    ].join("\n\n"),
  );
  const run = await storeRun(args.adminClient, {
    run_type: "chat",
    input_facts_hash: await hashJson(facts),
    input_snapshot: facts,
    prompt_text: args.question,
    model: MODEL,
    output_text: ai.text,
    structured_output: ai.structured,
    usage: ai.usage,
    status: "completed",
    requested_by: args.userId,
  });
  return {
    answer: ai.text,
    metrics: summarizeFacts(facts),
    anomalies: facts.clawd_anomaly_candidates_view ?? [],
    run,
  };
}

async function runTemplate(args: {
  adminClient: Client;
  openAiKey: string;
  userId: string | null;
  templateId: string;
  variables: Json;
}) {
  if (!args.templateId) return { error: "Select a prompt template first." };
  const { data: template, error } = await args.adminClient
    .from("ai_prompt_templates")
    .select("*")
    .eq("id", args.templateId)
    .maybeSingle();
  if (error || !template) throw new Error(error?.message ?? "Prompt not found");

  const rendered = renderTemplate(
    String(template.template_text),
    args.variables,
  );
  const facts = await loadFacts(args.adminClient, 100);
  const ai = await askOpenAI(
    args.openAiKey,
    [
      "Run this saved admin prompt against computed facts.",
      "Use human business terms only and recommend manual review where needed.",
      rendered,
      `Variables:\n${JSON.stringify(args.variables)}`,
      `Computed facts:\n${JSON.stringify(facts)}`,
    ].join("\n\n"),
  );
  const run = await storeRun(args.adminClient, {
    run_type: "prompt_template_run",
    prompt_template_id: args.templateId,
    input_facts_hash: await hashJson(facts),
    input_snapshot: facts,
    prompt_text: rendered,
    model: MODEL,
    output_text: ai.text,
    structured_output: ai.structured,
    usage: ai.usage,
    status: "completed",
    requested_by: args.userId,
  });
  return { answer: ai.text, run };
}

async function generateReport(args: {
  adminClient: Client;
  openAiKey: string;
  userId: string | null;
  reportType: "daily" | "monthly";
  force: boolean;
}) {
  const latest = await loadLatestPeriod(args.adminClient);
  const periodEnd = latest.periodEnd;
  const periodStart = args.reportType === "monthly"
    ? latest.periodStart
    : latest.periodEnd;

  if (!args.force) {
    const { data: existing } = await args.adminClient
      .from("ai_reports")
      .select("*, ai_runs(*)")
      .eq("report_type", args.reportType)
      .eq("period_start", periodStart)
      .eq("period_end", periodEnd)
      .maybeSingle();
    if (existing) return { report: existing, reused: true };
  }

  const detected = await detectAnomalies(args.adminClient, args.userId);
  const facts = await loadFacts(args.adminClient, 120, periodStart, periodEnd);
  const ai = await askOpenAI(
    args.openAiKey,
    [
      `Generate the ${args.reportType} Clawd operations report.`,
      "Explain major e-way, cost, delay, proof, acknowledgement, and route-cost risks.",
      "Recommend human actions and do not claim payment is blocked.",
      `Period: ${periodStart} to ${periodEnd}`,
      `Anomaly sync result:\n${JSON.stringify(detected)}`,
      `Computed facts:\n${JSON.stringify(facts)}`,
    ].join("\n\n"),
  );
  const riskScore = Number(ai.structured.risk_score ?? 0);
  const run = await storeRun(args.adminClient, {
    run_type: `${args.reportType}_report`,
    input_facts_hash: await hashJson(facts),
    input_snapshot: facts,
    prompt_text: `${args.reportType} report ${periodStart} to ${periodEnd}`,
    model: MODEL,
    output_text: ai.text,
    structured_output: ai.structured,
    usage: ai.usage,
    status: "completed",
    requested_by: args.userId,
  });
  const { data: report, error } = await args.adminClient
    .from("ai_reports")
    .upsert(
      {
        report_type: args.reportType,
        period_start: periodStart,
        period_end: periodEnd,
        summary: ai.text,
        recommendations: ai.structured.recommended_actions ?? [],
        risk_score: Number.isFinite(riskScore) ? riskScore : 0,
        ai_run_id: run?.id ?? null,
      },
      { onConflict: "report_type,period_start,period_end" },
    )
    .select()
    .single();
  if (error) throw new Error(error.message);

  if (args.reportType === "daily") {
    await args.adminClient.from("ai_daily_reports").upsert(
      {
        report_date: periodEnd,
        summary: ai.text,
        anomalies: detected.events ?? [],
        metrics: summarizeFacts(facts),
        generated_by: args.userId,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "report_date" },
    );
  }

  return { report, run, detected, reused: false };
}

async function detectAnomalies(adminClient: Client, userId: string | null) {
  const { data, error } = await adminClient
    .from("clawd_anomaly_candidates_view")
    .select("*")
    .order("business_priority_score", { ascending: false })
    .limit(150);
  if (error) throw new Error(error.message);

  const candidates = (data ?? []) as Json[];
  const events: Json[] = [];
  for (const candidate of candidates) {
    const payload = {
      signal_type: candidate.signal_type,
      severity: candidate.severity,
      entity_type: candidate.entity_type ?? "freight",
      freight_id: candidate.freight_id ?? null,
      invoice_id: candidate.invoice_id ?? null,
      transporter_id: candidate.transporter_id ?? null,
      route_key: candidate.route_key ?? null,
      company_name: candidate.company_name ?? null,
      evidence: candidate.evidence ?? {},
      metrics: candidate.metrics ?? {},
      business_priority_score: Number(candidate.business_priority_score ?? 0),
      status: "open",
    };
    const { data: event, error: eventError } = await adminClient
      .from("ai_anomaly_events")
      .upsert(payload, {
        onConflict:
          "signal_type,freight_id,invoice_id,transporter_id,route_key",
      })
      .select()
      .single();
    if (eventError) throw new Error(eventError.message);
    events.push(event as Json);

    if (["critical", "high"].includes(String(candidate.severity))) {
      await createAdminAlert(adminClient, candidate);
    }
  }
  return { scanned: candidates.length, stored: events.length, events };
}

async function createAdminAlert(adminClient: Client, candidate: Json) {
  const signal = String(candidate.signal_type ?? "risk");
  const freightId = candidate.freight_id as string | undefined;
  if (!freightId) return;

  const { data: existing } = await adminClient
    .from("admin_alerts")
    .select("id")
    .eq("freight_id", freightId)
    .eq("category", `ai_${signal}`)
    .eq("status", "open")
    .limit(1);
  if ((existing ?? []).length > 0) return;

  await adminClient.from("admin_alerts").insert({
    freight_id: freightId,
    invoice_id: candidate.invoice_id ?? null,
    category: `ai_${signal}`,
    severity: candidate.severity ?? "high",
    title: titleForSignal(signal),
    message: messageForSignal(candidate),
    metadata: {
      source: "clawd",
      signal_type: signal,
      invoice_id: candidate.invoice_id ?? null,
      transporter_id: candidate.transporter_id ?? null,
      route_key: candidate.route_key ?? null,
      evidence: candidate.evidence ?? {},
      metrics: candidate.metrics ?? {},
      business_priority_score: Number(candidate.business_priority_score ?? 0),
    },
    status: "open",
  });
}

async function loadFacts(
  client: Client,
  maxRows: number,
  periodStart: string | null = null,
  periodEnd: string | null = null,
): Promise<Json> {
  const { data: snapshot, error: snapshotError } = await client.rpc(
    "clawd_admin_snapshot",
    { p_period_start: periodStart, p_period_end: periodEnd },
  );
  if (snapshotError) throw new Error(snapshotError.message);

  const { data: candidates, error: candidateError } = await client
    .from("clawd_anomaly_candidates_view")
    .select("*")
    .order("business_priority_score", { ascending: false })
    .limit(maxRows);
  if (candidateError) throw new Error(candidateError.message);

  const { data: events, error: eventError } = await client
    .from("ai_anomaly_events")
    .select("*")
    .neq("status", "resolved")
    .order("business_priority_score", { ascending: false })
    .order("detected_at", { ascending: false })
    .limit(40);
  if (eventError) throw new Error(eventError.message);

  const { data: reports, error: reportError } = await client
    .from("ai_reports")
    .select(
      "report_type, period_start, period_end, risk_score, recommendations",
    )
    .order("period_end", { ascending: false })
    .limit(6);
  if (reportError) throw new Error(reportError.message);

  return {
    clawd_admin_snapshot: snapshot ?? {},
    clawd_anomaly_candidates_view: candidates ?? [],
    ai_anomaly_events: events ?? [],
    ai_reports: reports ?? [],
  };
}

async function loadLatestPeriod(client: Client) {
  const { data, error } = await client.rpc("clawd_latest_business_period");
  if (error) throw new Error(error.message);
  const first = Array.isArray(data) ? asRecord(data[0]) : asRecord(data);
  const today = new Date().toISOString().slice(0, 10);
  return {
    periodStart: String(first.period_start ?? today),
    periodEnd: String(first.period_end ?? today),
  };
}

function summarizeFacts(facts: Json) {
  const snapshot = asRecord(facts.clawd_admin_snapshot);
  const totals = asRecord(snapshot.totals);
  const riskSummary = asRecord(snapshot.risk_summary);
  const anomalies =
    (facts.clawd_anomaly_candidates_view as unknown[] | undefined) ?? [];
  return {
    ledger_rows: Number(totals.dispatches ?? 0),
    freight: Number(totals.freight ?? 0),
    pod_pending: Number(totals.pod_pending ?? 0),
    review_value: Number(totals.review_value ?? 0),
    anomaly_candidates: anomalies.length,
    duplicate_eway_risks: Number(riskSummary.duplicate_eway_risks ?? 0),
    route_cost_spike_risks: Number(riskSummary.route_cost_spike_risks ?? 0),
    high_extra_charge_risks: Number(riskSummary.high_extra_charge_risks ?? 0),
    open_alerts: Number(riskSummary.open_alerts ?? 0),
  };
}

async function askOpenAI(apiKey: string, prompt: string) {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      instructions: systemInstructions,
      input: prompt,
      reasoning: { effort: "medium" },
      max_output_tokens: 2200,
      text: {
        format: {
          type: "json_schema",
          name: "clawd_business_response",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              summary: { type: "string" },
              risk_level: {
                type: "string",
                enum: ["low", "medium", "high", "critical"],
              },
              risk_score: { type: "number" },
              business_impact: { type: "string" },
              evidence_summary: { type: "string" },
              recommended_actions: { type: "array", items: { type: "string" } },
              follow_up_questions: { type: "array", items: { type: "string" } },
              confidence: { type: "number" },
              plain_english_explanation: { type: "string" },
            },
            required: [
              "summary",
              "risk_level",
              "risk_score",
              "business_impact",
              "evidence_summary",
              "recommended_actions",
              "follow_up_questions",
              "confidence",
              "plain_english_explanation",
            ],
          },
        },
      },
    }),
  });
  const raw = await response.json();
  if (!response.ok) {
    throw new Error(raw?.error?.message ?? "OpenAI request failed");
  }

  const output = extractOutputText(raw);
  const structured = safeParseJson(output);
  const text = cleanBusinessText(
    String(
      structured.plain_english_explanation ||
        structured.summary ||
        output ||
        "",
    ),
  );
  return { text, structured, usage: raw.usage ?? {} };
}

async function storeRun(client: Client, payload: Json) {
  const { data, error } = await client.from("ai_runs").insert(payload).select()
    .single();
  if (error) throw new Error(error.message);
  return data;
}

function renderTemplate(template: string, variables: Json) {
  return template.replace(
    /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g,
    (_, key) => String(variables[key] ?? `{{${key}}}`),
  );
}

function titleForSignal(signal: string) {
  const labels: Record<string, string> = {
    eway_mismatch: "E-way or GR details need review",
    duplicate_eway: "Duplicate e-way bill risk",
    route_cost_spike: "Route cost spike detected",
    high_extra_charge: "High extra charges detected",
    proof_or_ack_delay: "Proof or acknowledgement delay",
  };
  return labels[signal] ?? "Clawd detected an operational risk";
}

function messageForSignal(candidate: Json) {
  const signal = String(candidate.signal_type ?? "risk").replaceAll("_", " ");
  const route = candidate.route_key ? ` on ${candidate.route_key}` : "";
  const company = candidate.company_name
    ? ` for ${candidate.company_name}`
    : "";
  return `Clawd found a ${signal}${route}${company}. Review the evidence before payment or closure.`;
}

function extractOutputText(data: Json) {
  if (typeof data.output_text === "string") return data.output_text;
  const parts: string[] = [];
  for (const item of (data.output as unknown[] | undefined) ?? []) {
    const record = asRecord(item);
    for (const content of (record.content as unknown[] | undefined) ?? []) {
      const contentRecord = asRecord(content);
      if (typeof contentRecord.text === "string") {
        parts.push(contentRecord.text);
      }
    }
  }
  return parts.join("\n").trim();
}

function safeParseJson(text: string): Json {
  try {
    return JSON.parse(text) as Json;
  } catch (_) {
    return {
      summary: text,
      risk_level: "medium",
      risk_score: 0,
      business_impact: "",
      evidence_summary: "",
      recommended_actions: [],
      follow_up_questions: [],
      confidence: 0,
      plain_english_explanation: text,
    };
  }
}

async function hashJson(value: unknown) {
  const bytes = new TextEncoder().encode(JSON.stringify(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function safeJson(req: Request): Promise<Json> {
  try {
    return await req.json();
  } catch (_) {
    return {};
  }
}

function asRecord(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Json)
    : {};
}

function cleanBusinessText(text: string) {
  return text
    .replace(
      /\b(?:admin_alerts|profiles|freights|bids|metrics|metadata|vehicles|drivers|invoices|delivery_stages|ai_runs|ai_reports|ai_anomaly_events|clawd_[a-z_]+)(?:\.[a-z_]+)?\b/gi,
      "business records",
    )
    .replace(
      /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi,
      "one record",
    )
    .replace(
      /\b(?:rows?|columns?|fields?|tables?|views?|JSON|SQL|UUIDs?)\b/gi,
      "details",
    )
    .replace(
      /\b(?:payment is blocked|payment blocked|blocked payment|payment has been blocked|payment was blocked)\b/gi,
      "payment needs manual review",
    )
    .replace(/\b(?:pod|eway|gr|lr)\b/gi, (match) => match.toUpperCase())
    .replace(/\b_+\b/g, " ")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
