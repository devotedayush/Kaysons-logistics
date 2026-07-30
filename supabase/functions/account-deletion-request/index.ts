import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const allowedOrigins = new Set([
  "https://devotedayush.github.io",
  "https://kaysons-logistics.vercel.app",
]);

function corsHeaders(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  return {
    "Access-Control-Allow-Origin": allowedOrigins.has(origin)
      ? origin
      : "https://devotedayush.github.io",
    "Access-Control-Allow-Headers": "content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

function json(req: Request, body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function normalizedEmail(value: unknown) {
  const email = String(value ?? "").trim().toLowerCase();
  if (
    email.length < 3 ||
    email.length > 320 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    return null;
  }
  return email;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return json(req, { error: "Method not allowed." }, 405);
  }

  const contentType = req.headers.get("content-type") ?? "";
  if (!contentType.includes("application/json")) {
    return json(req, { error: "Send a JSON request." }, 415);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(req, { error: "The request could not be read." }, 400);
  }

  // Hidden field used by the public form. A filled value is almost always a bot.
  if (String(body.company_website ?? "").trim()) {
    return json(req, {
      accepted: true,
      message: "If the account exists, the request has been recorded.",
    });
  }

  const email = normalizedEmail(body.email);
  const reason = String(body.reason ?? "").trim();
  const confirmed = body.confirmed === true;
  if (!email || !confirmed || reason.length > 1000) {
    return json(
      req,
      {
        error:
          "Enter a valid account email and confirm that you want the account and associated data deleted.",
      },
      400,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json(req, { error: "Deletion requests are temporarily unavailable." }, 503);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error } = await admin.from("account_deletion_requests").insert({
    email,
    source: "web",
    status: "pending",
    reason: reason || null,
  });

  // A duplicate means an active request already exists. Return the same generic
  // result so the endpoint does not disclose whether an email is registered.
  if (error && error.code !== "23505") {
    console.error("account deletion request insert failed", error.code);
    return json(req, { error: "The request could not be recorded. Try again later." }, 500);
  }

  return json(req, {
    accepted: true,
    message:
      "Your request has been recorded. Kaysons Logistics will verify it using the registered email and normally complete it within 30 days.",
  });
});
