import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Json = Record<string, unknown>;

const MODEL = "gpt-5.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-clawd-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const factSources = [
  "admin_freight_ledger_view",
  "admin_transporter_summary_view",
  "admin_company_summary_view",
  "admin_company_transporter_summary_view",
  "admin_town_summary_view",
  "admin_ack_summary_view",
  "clawd_freight_fact_view",
  "clawd_route_cost_baseline_view",
  "clawd_transporter_performance_view",
  "clawd_eway_reconciliation_view",
  "clawd_charge_risk_view",
  "clawd_delay_risk_view",
  "clawd_anomaly_candidates_view",
  "ai_anomaly_events",
  "admin_alerts",
];

const systemInstructions = [
  "You are Clawd, the backend operations analyst for Kaysons Logistics.",
  "Supabase SQL is the facts engine. Do not calculate raw totals yourself.",
  "Use only the computed facts and anomaly candidates provided by the backend.",
  "Your job is to explain what changed, why it matters, fraud or loss risk, and what action an admin, accountant, or logistics manager should take.",
  "Write for a non-technical logistics owner.",
  "Never expose database table names, raw column names, JSON paths, SQL phrases, UUIDs, or implementation details.",
  "Never mention words like table, column, row, JSON, SQL, view, UUID, schema, function, API, or database in the final answer.",
  "Translate internal signals into business language: late delivery proof, missing POD, duplicate e-way bill, cost spike, extra charge risk, or acknowledgement delay.",
  "Do not accuse anyone of fraud as fact. Say 'risk', 'possible issue', or 'needs review' unless the provided facts are conclusive.",
  "Do not say payment is blocked, held, or cannot be cleared. Say the item should be reviewed before payment release.",
  "If someone asks whether payment is blocked, answer: 'No automatic payment stop is applied in v1, but manual review before release is recommended for risky shipments.'",
  "Answer like a calm human operations manager: short, direct, practical, and free of technical implementation details.",
  "Prefer concise markdown with headings and bullets.",
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
          "Clawd is not fully configured. Set SUPABASE_SERVICE_ROLE_KEY and OPENAI_API_KEY as Edge Function secrets.",
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
      const result = await detectAnomalies(adminClient, auth.userId);
      return json(result);
    }

    if (action === "daily_report" || action === "monthly_report") {
      const result = await generateReport({
        adminClient,
        openAiKey,
        userId: auth.userId,
        reportType: action === "monthly_report" ? "monthly" : "daily",
        force: body.force === true,
      });
      return json(result);
    }

    if (action === "template_run") {
      const result = await runTemplate({
        adminClient,
        openAiKey,
        userId: auth.userId,
        templateId: String(body.template_id ?? ""),
        variables: asRecord(body.variables),
      });
      return json(result);
    }

    const question = String(body.question ?? "").trim();
    if (!question) return json({ error: "Ask Clawd a question first." }, 400);
    const result = await chat({
      adminClient,
      openAiKey,
      userId: auth.userId,
      question,
    });
    return json(result);
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

async function authenticate(req: Request, supabaseUrl: string, anonKey: string) {
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
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser(token);
  if (userError || !user) {
    return { ok: false as const, status: 401, error: "Invalid session" };
  }
  const { data: profile, error: profileError } = await userClient
    .from("profiles")
    .select("id, role")
    .eq("id", user.id)
    .maybeSingle();
  const role = String(profile?.role ?? "");
  if (profileError || !["admin", "accountant", "logistics_manager"].includes(role)) {
    return {
      ok: false as const,
      status: 403,
      error: "Clawd is available to admins, accountants, and logistics managers only",
    };
  }
  return { ok: true as const, userId: user.id };
}

async function chat(args: {
  adminClient: ReturnType<typeof createClient>;
  openAiKey: string;
  userId: string | null;
  question: string;
}) {
  const facts = await loadFacts(args.adminClient, 80);
  const prompt = [
    "Answer the staff question using the computed logistics facts.",
    "Do not invent numbers. If the facts are insufficient, say what extra business detail is needed.",
    "Use human business terms only. Do not name backend sources, fields, IDs, or implementation details.",
    "For payment-sensitive risks, recommend manual review before payment release; do not claim the system has blocked or held payment.",
    `Question: ${args.question}`,
    `Computed facts:\n${JSON.stringify(facts)}`,
  ].join("\n\n");
  const ai = await askOpenAI(args.openAiKey, prompt);
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
  adminClient: ReturnType<typeof createClient>;
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
  const rendered = renderTemplate(String(template.template_text), args.variables);
  const facts = await loadFacts(args.adminClient, 100);
  const prompt = [
    "Run this saved admin prompt against computed facts.",
    "Use human business terms only. Do not name backend sources, fields, IDs, or implementation details.",
    "For payment-sensitive risks, recommend manual review before payment release; do not claim the system has blocked or held payment.",
    rendered,
    `Variables:\n${JSON.stringify(args.variables)}`,
    `Computed facts:\n${JSON.stringify(facts)}`,
  ].join("\n\n");
  const ai = await askOpenAI(args.openAiKey, prompt);
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
  adminClient: ReturnType<typeof createClient>;
  openAiKey: string;
  userId: string | null;
  reportType: "daily" | "monthly";
  force: boolean;
}) {
  const now = new Date();
  const periodEnd = now.toISOString().slice(0, 10);
  const periodStart =
    args.reportType === "monthly"
      ? new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
          .toISOString()
          .slice(0, 10)
      : periodEnd;

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
  const facts = await loadFacts(args.adminClient, 120);
  const prompt = [
    `Generate the ${args.reportType} Clawd operations report.`,
    "Explain major fraud, e-way, cost, delay, proof, acknowledgement, and route-cost risks.",
    "Recommend human actions. Do not say the system blocked or held payment.",
    "Use human business terms only. Do not name backend sources, fields, IDs, or implementation details.",
    `Period: ${periodStart} to ${periodEnd}`,
    `Anomaly sync result:\n${JSON.stringify(detected)}`,
    `Computed facts:\n${JSON.stringify(facts)}`,
  ].join("\n\n");
  const ai = await askOpenAI(args.openAiKey, prompt);
  const riskScore = Number(ai.structured.risk_score ?? 0);
  const run = await storeRun(args.adminClient, {
    run_type: `${args.reportType}_report`,
    input_facts_hash: await hashJson(facts),
    input_snapshot: facts,
    prompt_text: prompt,
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

async function detectAnomalies(
  adminClient: ReturnType<typeof createClient>,
  userId: string | null,
) {
  const { data, error } = await adminClient
    .from("clawd_anomaly_candidates_view")
    .select("*")
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
      status: "open",
    };
    const { data: event, error: eventError } = await adminClient
      .from("ai_anomaly_events")
      .upsert(payload, {
        onConflict: "signal_type,freight_id,invoice_id,transporter_id,route_key",
      })
      .select()
      .single();
    if (eventError) throw new Error(eventError.message);
    events.push(event as Json);

    if (["critical", "high"].includes(String(candidate.severity))) {
      await createAdminAlert(adminClient, candidate, userId);
    }
  }
  return { scanned: candidates.length, stored: events.length, events };
}

async function createAdminAlert(
  adminClient: ReturnType<typeof createClient>,
  candidate: Json,
  _userId: string | null,
) {
  const signal = String(candidate.signal_type ?? "risk");
  const freightId = candidate.freight_id as string | undefined;
  if (!freightId) return;
  const metadata = {
    source: "clawd",
    signal_type: signal,
    invoice_id: candidate.invoice_id ?? null,
    transporter_id: candidate.transporter_id ?? null,
    route_key: candidate.route_key ?? null,
    evidence: candidate.evidence ?? {},
    metrics: candidate.metrics ?? {},
  };
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
    metadata,
    status: "open",
  });
}

async function loadFacts(
  client: ReturnType<typeof createClient>,
  maxRows: number,
): Promise<Json> {
  const snapshot: Json = {};
  for (const source of factSources) {
    const { data, error } = await client.from(source).select("*").limit(maxRows);
    snapshot[source] = error ? [] : data ?? [];
  }
  return snapshot;
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
              recommended_actions: {
                type: "array",
                items: { type: "string" },
              },
              follow_up_questions: {
                type: "array",
                items: { type: "string" },
              },
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
  const text = sanitizeBusinessText(
    String(
      structured.plain_english_explanation ||
        structured.summary ||
        output ||
        "",
    ),
  );
  return { text, structured, usage: raw.usage ?? {} };
}

async function storeRun(client: ReturnType<typeof createClient>, payload: Json) {
  const { data, error } = await client.from("ai_runs").insert(payload).select().single();
  if (error) throw new Error(error.message);
  return data;
}

function summarizeFacts(facts: Json) {
  const ledger = (facts.admin_freight_ledger_view as unknown[] | undefined) ?? [];
  const anomalies =
    (facts.clawd_anomaly_candidates_view as unknown[] | undefined) ?? [];
  const alerts = (facts.admin_alerts as unknown[] | undefined) ?? [];
  return {
    ledger_rows: ledger.length,
    anomaly_candidates: anomalies.length,
    alerts: alerts.length,
  };
}

function renderTemplate(template: string, variables: Json) {
  return template.replace(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g, (_, key) =>
    String(variables[key] ?? `{{${key}}}`)
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
  const company = candidate.company_name ? ` for ${candidate.company_name}` : "";
  return `Clawd found a ${signal}${route}${company}. Review the evidence before payment or closure.`;
}

function extractOutputText(data: Json) {
  if (typeof data.output_text === "string") return data.output_text;
  const parts: string[] = [];
  for (const item of (data.output as unknown[] | undefined) ?? []) {
    const record = asRecord(item);
    for (const content of (record.content as unknown[] | undefined) ?? []) {
      const contentRecord = asRecord(content);
      if (typeof contentRecord.text === "string") parts.push(contentRecord.text);
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

function sanitizeBusinessText(text: string): string {
  return text
    .replace(/\b(?:admin_alerts|profiles|freights|bids|metadata|metrics|vehicles|drivers|invoices|delivery_stages|ai_runs|ai_reports|ai_anomaly_events|clawd_[a-z_]+)(?:\.[a-z_]+)+/gi, "this item")
    .replace(/\b(?:admin_alerts|profiles|freights|bids|metadata|metrics|vehicles|drivers|invoices|delivery_stages|ai_runs|ai_reports|ai_anomaly_events|clawd_[a-z_]+)\b/gi, "business records")
    .replace(/\b[a-z]+(?:_[a-z0-9]+){1,}\b/gi, (match) => humanizeSnakeCase(match))
    .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, "one record")
    .replace(/\brows?\b/gi, "records")
    .replace(/\bcolumns?\b/gi, "details")
    .replace(/\bfields?\b/gi, "details")
    .replace(/\btables?\b/gi, "records")
    .replace(/\bviews?\b/gi, "reports")
    .replace(/\bJSON\b/gi, "details")
    .replace(/\bSQL\b/gi, "backend checks")
    .replace(/\bUUIDs?\b/gi, "record IDs")
    .replace(/\bIs payment needs manual review\?\s*/gi, "")
    .replace(/\bthere(?:'s| is) no indication that payment is (?:automatically )?blocked\.?\s*/gi, "No automatic payment stop is applied. ")
    .replace(/\b(?:payment is (?:automatically )?blocked|payment (?:automatically )?blocked|blocked payment|payment has been blocked|payment was blocked)\b/gi, "payment needs manual review")
    .replace(/\b(?:Is )?payment needs manual review\?\s*No\.?\s*/gi, "")
    .replace(/\bNothing here says payment needs manual review\.?\s*/gi, "No automatic payment stop is applied. ")
    .replace(/(?:#{1,6}\s*)?[—-]?\s*\bthere(?:'s| is) no indication that payment needs manual review\.?\s*/gi, "No automatic payment stop is applied. ")
    .replace(/\b(?:blocked|held|cannot be cleared|should not be cleared) for payment\b/gi, "marked for review before payment release")
    .replace(/\bblocked\b/gi, "on automatic stop")
    .replace(/\bautomatic payment stop is applied in v1\b/gi, "No automatic payment stop is applied right now")
    .replace(/[—-]\s*there is no automatic payment stop in v1/gi, "No automatic payment stop is applied right now")
    .replace(/\bautomatic payment stop in v1\b/gi, "automatic payment stop right now")
    .replace(/\s+/g, " ")
    .trim();
}

function humanizeSnakeCase(value: string): string {
  const labels: Record<string, string> = {
    pod_late_flag: "late POD",
    pod_missing_overdue_flag: "overdue missing POD",
    pod_delay_days: "POD delay days",
    pod_submitted_at: "POD submission time",
    proof_or_ack_delay: "proof or acknowledgement delay",
    duplicate_eway: "duplicate e-way bill",
    eway_mismatch: "e-way bill mismatch",
    route_cost_spike: "route cost spike",
    high_extra_charge: "high extra charge",
    ack_pending_days: "acknowledgement pending days",
    bill_to_dispatch_delay_days: "bill-to-dispatch delay days",
    pod_missing_flag: "missing POD",
    last_location_age_hours: "stale location update",
    risk_score: "risk score",
    risk_level: "risk level",
    recommended_actions: "recommended actions",
    evidence_summary: "evidence summary",
    business_impact: "business impact",
    follow_up_questions: "follow-up questions",
  };
  return labels[value.toLowerCase()] ?? value.replaceAll("_", " ");
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
