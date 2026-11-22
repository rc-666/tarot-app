// delete-account: called from Settings > Delete account (6b) with the user's own JWT.
// Deletes the auth user; profiles, readings and personal cards are removed by ON DELETE CASCADE.
import { createClient } from "@supabase/supabase-js";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  const auth = req.headers.get("Authorization") ?? "";
  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) return new Response("unauthorized", { status: 401 });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const del = await admin.auth.admin.deleteUser(data.user.id);
  if (del.error) {
    console.error(del.error);
    return Response.json({ error: "delete_failed" }, { status: 500 });
  }
  return Response.json({ deleted: true });
});
