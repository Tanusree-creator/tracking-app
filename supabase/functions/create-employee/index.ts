// Deploy: supabase functions deploy create-employee
// Runs inside Supabase, so the service-role key never ships in the Flutter app.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = Deno.env.get("SUPABASE_URL")!;
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await caller.auth.getUser();
  if (!user) return json({ error: "Not signed in." }, 401);
  if (user.app_metadata?.role !== "admin") {
    return json({ error: "Only admins can create users." }, 403);
  }

  const { name, email, password, phone, role } = await req.json();
  if (!name || !email || !password) return json({ error: "Name, email and password are required." }, 400);
  if (String(password).length < 8) return json({ error: "Password must be at least 8 characters." }, 400);
  const newRole = role === "admin" ? "admin" : "tech";

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    app_metadata: { role: newRole },
    user_metadata: { name },
  });
  if (error) return json({ error: error.message }, 400);

  const { error: rowError } = await admin
    .from("employees")
    .upsert({ id: data.user.id, name, email, phone: phone ?? null, role: newRole });
  if (rowError) {
    await admin.auth.admin.deleteUser(data.user.id); // don't leave a login without a profile
    return json({ error: `Profile not saved: ${rowError.message}` }, 400);
  }
  return json({ id: data.user.id });
});
