import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type SnapshotTable = {
  name: string;
  count: number | null;
  rows: Record<string, unknown>[];
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const tables = [
  "profiles",
  "bank_accounts",
  "vehicles",
  "drivers",
  "documents",
  "freights",
  "bids",
  "freight_preferred_transporters",
  "freight_blocked_transporters",
  "invoices",
  "freight_charges",
  "admin_alerts",
  "ai_daily_reports",
];

const plainEnglishStyleGuide = [
  "Write for a non-technical logistics owner, not a developer.",
  "Use the database only as private evidence. Never expose raw table names, column names, JSON paths, SQL-style phrases, or field=value pairs.",
  "Never write words like profiles, admin_alerts, freights, bids, winner_profile_id, metadata, row, table, column, null, or UUID unless the admin explicitly asks for technical detail.",
  "Avoid raw record IDs. If a record has no human label, say 'one freight' or 'one transporter record'.",
  "Prefer business words: freight, bid, transporter, driver, vehicle, invoice, alert, missing document, route, amount, status.",
  "Explain why each issue matters in plain English and what the admin should do next.",
  "Keep numbers human-friendly. For rupee amounts, use commas and the rupee symbol when possible.",
  "Use short markdown with headings and bullets. Do not start with a database inventory unless the user asks for counts.",
  "Do not include an Evidence section. Instead, phrase evidence naturally, for example: 'Karan Transport is missing RC and insurance details'.",
].join("\n");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

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

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) return json({ error: "Missing admin session" }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser(token);
  if (userError || !user) return json({ error: "Invalid session" }, 401);

  const { data: profile, error: profileError } = await userClient
    .from("profiles")
    .select("id, email, full_name, role")
    .eq("id", user.id)
    .maybeSingle();
  if (profileError || profile?.role !== "admin") {
    return json({ error: "Clawd is available to admins only" }, 403);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const body = await safeJson(req);
  const action = (body.action ?? "chat").toString();
  const maxRows = Math.min(Number(body.maxRows ?? 350), 1000);
  const snapshot = await loadSnapshot(adminClient, maxRows);
  const metrics = buildMetrics(snapshot);
  const anomalies = detectAnomalies(snapshot, metrics);
  const operationsBrief = buildOperationsBrief(snapshot);

  if (action === "daily_report") {
    const today = new Date().toISOString().slice(0, 10);
    const force = body.force === true;
    if (!force) {
      const { data: existing } = await adminClient
        .from("ai_daily_reports")
        .select("*")
        .eq("report_date", today)
        .maybeSingle();
      if (existing) return json({ report: existing, metrics });
    }

    const prompt = [
      "Generate today's admin operations report for Kaysons Logistics.",
      "Call out anomalies, suspicious mismatches, slow bids, vehicle/document issues, and money/freight outliers.",
      "Return concise markdown with sections: What needs attention, Why it matters, Recommended actions, Numbers to watch.",
      "Do not include a raw database summary. Only include counts when they support a business point.",
      "You are not allowed to mention database names, record IDs, field names, or technical evidence. Use only the operations brief below.",
      `Response style:\n${plainEnglishStyleGuide}`,
      `Operations brief:\n${operationsBrief}`,
    ].join("\n\n");
    const summary = await askOpenAI(openAiKey, prompt);

    const { data: report, error: upsertError } = await adminClient
      .from("ai_daily_reports")
      .upsert(
        {
          report_date: today,
          summary,
          anomalies,
          metrics,
          generated_by: user.id,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "report_date" },
      )
      .select()
      .single();
    if (upsertError) return json({ error: upsertError.message }, 500);
    return json({ report, metrics });
  }

  const question = (body.question ?? "").toString().trim();
  if (!question) return json({ error: "Ask Clawd a question first." }, 400);

  const prompt = [
    "You are Clawd, the admin AI analyst for Kaysons Logistics.",
    "Use the operations brief below. If the detail is insufficient, say what extra business detail is missing.",
    "Be direct, operational, and careful with money, transporter, vehicle, bid, invoice, and mismatch analysis.",
    "Always include anomalies or risks you notice, even if the admin did not ask directly.",
    "Answer the user's question first. Then add risks and next actions if useful.",
    "You are not allowed to mention database names, record IDs, field names, or technical evidence. Use only the operations brief below.",
    `Response style:\n${plainEnglishStyleGuide}`,
    `Admin question: ${question}`,
    `Operations brief:\n${operationsBrief}`,
  ].join("\n\n");

  const answer = await askOpenAI(openAiKey, prompt);
  return json({ answer, metrics, anomalies });
});

async function safeJson(req: Request): Promise<Record<string, unknown>> {
  try {
    return await req.json();
  } catch (_) {
    return {};
  }
}

async function loadSnapshot(
  client: ReturnType<typeof createClient>,
  maxRows: number,
): Promise<SnapshotTable[]> {
  const snapshot: SnapshotTable[] = [];
  for (const table of tables) {
    try {
      const { count } = await client
        .from(table)
        .select("*", { count: "exact", head: true });
      const { data, error } = await client
        .from(table)
        .select("*")
        .limit(maxRows);
      if (error) {
        snapshot.push({ name: table, count: count ?? null, rows: [] });
      } else {
        snapshot.push({
          name: table,
          count: count ?? null,
          rows: (data ?? []) as Record<string, unknown>[],
        });
      }
    } catch (_) {
      snapshot.push({ name: table, count: null, rows: [] });
    }
  }
  return snapshot;
}

function buildMetrics(snapshot: SnapshotTable[]) {
  const get = (name: string) => snapshot.find((table) => table.name === name)?.rows ?? [];
  const freights = get("freights");
  const bids = get("bids");
  const alerts = get("admin_alerts");
  const profiles = get("profiles");
  const vehicles = get("vehicles");
  const invoices = get("invoices");

  const statusCounts: Record<string, number> = {};
  for (const freight of freights) {
    const status = String(freight.status ?? "unknown");
    statusCounts[status] = (statusCounts[status] ?? 0) + 1;
  }

  const bidAmounts = bids
    .map((bid) => Number(bid.amount ?? 0))
    .filter((amount) => Number.isFinite(amount) && amount > 0);
  const avgBid =
    bidAmounts.length === 0
      ? 0
      : bidAmounts.reduce((sum, value) => sum + value, 0) / bidAmounts.length;

  return {
    generated_at: new Date().toISOString(),
    freights: { total: freights.length, by_status: statusCounts },
    bids: {
      total: bids.length,
      average_amount: Math.round(avgBid),
      min_amount: bidAmounts.length ? Math.min(...bidAmounts) : 0,
      max_amount: bidAmounts.length ? Math.max(...bidAmounts) : 0,
    },
    alerts: {
      total: alerts.length,
      open: alerts.filter((alert) => alert.status !== "resolved").length,
      high: alerts.filter((alert) =>
        ["high", "critical"].includes(String(alert.severity ?? "")),
      ).length,
    },
    profiles: {
      total: profiles.length,
      transporters: profiles.filter((p) => p.role === "transporter").length,
      logistics_managers: profiles.filter((p) => p.role === "logistics_manager").length,
      admins: profiles.filter((p) => p.role === "admin").length,
    },
    vehicles: {
      total: vehicles.length,
      missing_rc: vehicles.filter((v) => !String(v.rc_number ?? "").trim()).length,
      missing_insurance: vehicles.filter((v) =>
        !String(v.insurance_number ?? "").trim()
      ).length,
    },
    invoices: { total: invoices.length },
  };
}

function buildOperationsBrief(snapshot: SnapshotTable[]): string {
  const profiles = getRows(snapshot, "profiles");
  const freights = getRows(snapshot, "freights");
  const bids = getRows(snapshot, "bids");
  const alerts = getRows(snapshot, "admin_alerts");
  const vehicles = getRows(snapshot, "vehicles");
  const drivers = getRows(snapshot, "drivers");
  const invoices = getRows(snapshot, "invoices");

  const profilesById = new Map(
    profiles.map((profile) => [String(profile.id ?? ""), profile]),
  );
  const freightsById = new Map(
    freights.map((freight) => [String(freight.id ?? ""), freight]),
  );

  const freightStatusCounts: Record<string, number> = {};
  for (const freight of freights) {
    const status = cleanStatus(freight.status);
    freightStatusCounts[status] = (freightStatusCounts[status] ?? 0) + 1;
  }

  const lines: string[] = [
    `The app currently has ${freights.length} freight jobs, ${bids.length} bids, ${vehicles.length} vehicles, ${drivers.length} drivers, ${invoices.length} invoices, and ${profiles.length} user/company accounts.`,
    `Freight status mix: ${Object.entries(freightStatusCounts)
      .map(([status, count]) => `${count} ${status}`)
      .join(", ") || "no freight jobs yet"}.`,
  ];

  const openAlerts = alerts.filter((alert) =>
    String(alert.status ?? "").toLowerCase() !== "resolved"
  );
  const highAlerts = openAlerts.filter((alert) =>
    ["high", "critical"].includes(String(alert.severity ?? "").toLowerCase())
  );
  if (highAlerts.length) {
    lines.push(
      `${highAlerts.length} high-priority admin alert(s) are still open.`,
    );
    for (const alert of highAlerts.slice(0, 5)) {
      const freight = freightsById.get(String(alert.freight_id ?? ""));
      const metadata = asRecord(alert.metadata);
      const transporter = profileName(
        profilesById.get(String(metadata.winner_profile_id ?? "")),
      ) || profileName(profilesById.get(String(freight?.winner_profile_id ?? "")));
      const message = cleanBusinessSentence(
        textValue(alert, ["message", "title"]) || "Needs admin review",
      );
      lines.push(
        `- ${message}${transporter ? ` for ${transporter}` : ""}${
          freight ? ` on ${freightLabel(freight)}` : ""
        }.`,
      );
    }
  }

  const awardedNotDispatched = freights.filter((freight) =>
    cleanStatus(freight.status) === "awarded" && isBlank(freight.dispatched_at)
  );
  if (awardedNotDispatched.length) {
    lines.push(
      `${awardedNotDispatched.length} awarded freight job(s) have not been dispatched yet.`,
    );
    for (const freight of awardedNotDispatched.slice(0, 5)) {
      lines.push(
        `- ${freightLabel(freight)} is awarded but still waiting for dispatch action.`,
      );
    }
  }

  const dispatchedIssues = freights.filter((freight) =>
    cleanStatus(freight.status) === "dispatched" &&
    (isBlank(freight.vehicle_number) ||
      isBlank(freight.driver_name) ||
      isBlank(freight.driver_phone) ||
      !looksLikeVehicleNumber(String(freight.vehicle_number ?? "")))
  );
  if (dispatchedIssues.length) {
    lines.push(
      `${dispatchedIssues.length} dispatched freight job(s) have weak vehicle or driver details.`,
    );
    for (const freight of dispatchedIssues.slice(0, 5)) {
      const missing = [
        isBlank(freight.vehicle_number) ||
            !looksLikeVehicleNumber(String(freight.vehicle_number ?? ""))
          ? "valid vehicle number"
          : "",
        isBlank(freight.driver_name) ? "driver name" : "",
        isBlank(freight.driver_phone) ? "driver phone" : "",
      ].filter(Boolean);
      lines.push(`- ${freightLabel(freight)} is missing ${missing.join(", ")}.`);
    }
  }

  const suspiciousBids: string[] = [];
  for (const bid of bids) {
    const freight = freightsById.get(String(bid.freight_id ?? ""));
    const amount = Number(bid.amount ?? 0);
    const expected = Number(freight?.internal_calling_bid ?? 0);
    if (!Number.isFinite(amount) || amount <= 0) continue;
    if (amount < 1000 || (expected > 0 && (amount < expected * 0.5 || amount > expected * 1.25))) {
      const transporter = profileName(profilesById.get(String(bid.transporter_id ?? "")));
      const reason = amount < 1000
        ? "looks unrealistically low"
        : amount < expected * 0.5
        ? "is far below the expected freight amount"
        : "is above the expected freight amount";
      suspiciousBids.push(
        `${money(amount)} from ${transporter || "a transporter"} on ${
          freight ? freightLabel(freight) : "one freight job"
        } ${reason}${expected > 0 ? ` (${money(expected)} expected)` : ""}.`,
      );
    }
  }
  if (suspiciousBids.length) {
    lines.push(`${suspiciousBids.length} bid amount(s) need review.`);
    for (const issue of suspiciousBids.slice(0, 6)) lines.push(`- ${issue}`);
  }

  const transporterCompliance: string[] = [];
  for (const profile of profiles) {
    if (profile.role !== "transporter") continue;
    const missing = [
      isBlank(profile.rc_number) ? "RC details" : "",
      isBlank(profile.lorry_insurance_number) ? "insurance details" : "",
    ].filter(Boolean);
    if (missing.length) {
      transporterCompliance.push(
        `${profileName(profile)} is missing ${missing.join(" and ")}.`,
      );
    }
  }
  if (transporterCompliance.length) {
    lines.push(
      `${transporterCompliance.length} transporter account(s) have incomplete compliance details.`,
    );
    for (const issue of transporterCompliance.slice(0, 6)) lines.push(`- ${issue}`);
  }

  if (lines.length <= 2) {
    lines.push("No major anomalies were found in the current operations snapshot.");
  }

  return lines.join("\n");
}

function detectAnomalies(snapshot: SnapshotTable[], metrics: Record<string, unknown>) {
  const anomalies: Record<string, unknown>[] = [];
  const get = (name: string) => snapshot.find((table) => table.name === name)?.rows ?? [];
  const freights = get("freights");
  const bids = get("bids");
  const alerts = get("admin_alerts");

  const bidsByFreight = new Map<string, number[]>();
  for (const bid of bids) {
    const freightId = String(bid.freight_id ?? "");
    const amount = Number(bid.amount ?? 0);
    if (!freightId || !amount) continue;
    bidsByFreight.set(freightId, [...(bidsByFreight.get(freightId) ?? []), amount]);
  }

  for (const [freightId, amounts] of bidsByFreight.entries()) {
    if (amounts.length < 2) continue;
    const min = Math.min(...amounts);
    const max = Math.max(...amounts);
    if (min > 0 && max / min > 1.4) {
      anomalies.push({
        type: "bid_spread",
        severity: "medium",
        freight_id: freightId,
        message: `Bid spread is high: ${min} to ${max}.`,
      });
    }
  }

  for (const freight of freights) {
    const stages = (freight.delivery_stages ?? {}) as Record<string, unknown>;
    if (freight.status === "dispatched" && !stages.vehicle_confirmation) {
      anomalies.push({
        type: "vehicle_not_confirmed",
        severity: "high",
        freight_id: freight.id,
        message: "Vehicle was dispatched but has not been confirmed by LM.",
      });
    }
  }

  for (const alert of alerts) {
    if (alert.status !== "resolved") {
      anomalies.push({
        type: "open_alert",
        severity: alert.severity ?? "medium",
        freight_id: alert.freight_id,
        message: alert.title ?? "Open admin alert",
      });
    }
  }

  return anomalies.slice(0, 25);
}

function getRows(snapshot: SnapshotTable[], name: string): Record<string, unknown>[] {
  return snapshot.find((table) => table.name === name)?.rows ?? [];
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function textValue(row: Record<string, unknown>, keys: string[]): string {
  for (const key of keys) {
    const value = row[key];
    if (!isBlank(value)) return String(value).trim();
  }
  return "";
}

function profileName(profile: Record<string, unknown> | undefined): string {
  if (!profile) return "";
  return textValue(profile, ["business_name", "full_name", "email"]) ||
    "a transporter";
}

function freightLabel(freight: Record<string, unknown>): string {
  const origin = textValue(freight, ["origin", "pickup_city", "from_city"]);
  const destination = textValue(freight, [
    "destination_town",
    "destination",
    "drop_city",
    "to_city",
  ]);
  if (origin && destination) return `${origin} to ${destination}`;
  if (origin) return `freight from ${origin}`;
  if (destination) return `freight to ${destination}`;
  return "one freight job";
}

function cleanStatus(value: unknown): string {
  return String(value ?? "unknown").replace(/_/g, " ").trim() || "unknown";
}

function isBlank(value: unknown): boolean {
  return value === null || value === undefined || String(value).trim() === "";
}

function money(value: number): string {
  return `₹${Math.round(value).toLocaleString("en-IN")}`;
}

function looksLikeVehicleNumber(value: string): boolean {
  const compact = value.replace(/[^a-z0-9]/gi, "");
  return compact.length >= 8 && /[a-z]/i.test(compact) && /\d/.test(compact);
}

function cleanBusinessSentence(value: string): string {
  return value
    .replace(/\b[A-Za-z_]+\.[A-Za-z_]+\b/g, "detail")
    .replace(/\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/gi, "one record")
    .replace(/\b[0-9a-f]{7,}\.\.\./gi, "one record")
    .replace(/\s+/g, " ")
    .trim();
}

async function askOpenAI(apiKey: string, prompt: string): Promise<string> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-5.2",
      instructions:
        "You are a senior logistics operations analyst. Give plain-English business analysis for non-technical admins. Use database details internally only. Never expose raw table names, column names, JSON paths, field=value pairs, null values, or UUIDs unless the user explicitly asks for technical detail.",
      input: prompt,
      reasoning: { effort: "medium" },
      max_output_tokens: 2200,
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.message ?? "OpenAI request failed");
  }
  if (typeof data.output_text === "string") {
    return sanitizeBusinessText(data.output_text);
  }
  const parts: string[] = [];
  for (const item of data.output ?? []) {
    for (const content of item.content ?? []) {
      if (typeof content.text === "string") parts.push(content.text);
    }
  }
  return sanitizeBusinessText(parts.join("\n").trim());
}

function sanitizeBusinessText(text: string): string {
  const replacements: [RegExp, string][] = [
    [
      /\b(?:admin_alerts|profiles|freights|bids|metadata|metrics|vehicles|drivers|invoices)(?:\.[a-z_]+)+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s,)]+)/gi,
      "a technical detail",
    ],
    [
      /\b(?:admin_alerts|profiles|freights|bids|metadata|metrics|vehicles|drivers|invoices)(?:\.[a-z_]+)+\b/gi,
      "technical detail",
    ],
    [/\badmin_alerts\.status\s*=\s*["']?open["']?/gi, "open admin alert"],
    [/\badmin_alerts\.category\s*=\s*[\w_'-]+/gi, "alert type"],
    [/\badmin_alerts\.message\b/gi, "alert message"],
    [/\badmin_alerts\.metadata\.[\w_]+\b/gi, "alert details"],
    [/\badmin_alerts\b/gi, "admin alerts"],
    [/\bprofiles\.rc_number\s*=\s*null\b/gi, "RC number is missing"],
    [
      /\bprofiles\.lorry_insurance_number\s*=\s*null\b/gi,
      "insurance number is missing",
    ],
    [/\bprofiles\.[\w_]+\b/gi, "transporter detail"],
    [/\bfreights\.internal_calling_bid\b/gi, "expected freight amount"],
    [/\bfreights\.winner_profile_id\b/gi, "winning transporter"],
    [/\bfreights\.status\b/gi, "freight status"],
    [/\bfreights\.[\w_]+\b/gi, "freight detail"],
    [/\bbids\.amount\b/gi, "bid amount"],
    [/\bbids\.state\b/gi, "bid result"],
    [/\bbids\.freight_id\b/gi, "freight record"],
    [/\bbids\.[\w_]+\b/gi, "bid detail"],
    [/\bmetadata\.[\w_]+\b/gi, "details"],
    [/\bwinner_profile_id\b/gi, "winning transporter"],
    [/\bmissing_fields\b/gi, "missing details"],
    [/\bprofile fields?\b/gi, "transporter details"],
    [/\btable\b/gi, "record"],
    [/\brows?\b/gi, "records"],
    [/\bcolumns?\b/gi, "details"],
    [/\bnull\b/gi, "missing"],
    [
      /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi,
      "one record",
    ],
    [/\b(?:Freight|Bid|Alert)\s+[0-9a-f]{6,}[-\w]*\b/gi, "One record"],
    [/\b[0-9a-f]{7,}\.\.\./gi, "one record"],
    [/\([^)]*(?:admin_alerts|profiles|freights|bids|metadata|winner_profile_id)[^)]*\)/gi, ""],
  ];

  return replacements.reduce(
    (cleaned, [pattern, replacement]) => cleaned.replace(pattern, replacement),
    text,
  );
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
