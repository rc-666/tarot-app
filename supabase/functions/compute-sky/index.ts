// compute-sky: called daily by pg_cron (05:00 and 06:00 UTC). Service role only.
import { createClient } from "@supabase/supabase-js";
import { runSkyJob, type Db, type ProfileRow } from "../_shared/job.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.headers.get("Authorization") !== `Bearer ${serviceKey}`) {
    return new Response("forbidden", { status: 403 });
  }
  const sb = createClient(url, serviceKey, { auth: { persistSession: false } });
  const check = (r: { error: { message: string } | null }) => {
    if (r.error) throw new Error(r.error.message);
  };
  const db: Db = {
    async upsert(table, rows, onConflict) {
      for (let i = 0; i < rows.length; i += 1000) {
        check(await sb.from(table).upsert(rows.slice(i, i + 1000), { onConflict }));
      }
    },
    async profilesPage(afterId, limit) {
      let q = sb.from("profiles")
        .select("id,sun_sign,tz,birth_date,birth_time,birth_tz,natal_sun,natal_moon")
        .order("id").limit(limit);
      if (afterId) q = q.gt("id", afterId);
      const r = await q;
      check(r);
      return (r.data ?? []) as ProfileRow[];
    },
    async setNatal(id, sun, moon, sunSign) {
      check(await sb.from("profiles").update({ natal_sun: sun, natal_moon: moon, sun_sign: sunSign }).eq("id", id));
    },
    async deleteBefore(table, column, value) {
      check(await sb.from(table).delete().lt(column, value));
    },
  };
  try {
    const result = await runSkyJob(db, new Date());
    console.log(JSON.stringify(result));
    return Response.json(result, { status: result.errors.length ? 207 : 200 });
  } catch (e) {
    console.error(e);
    return Response.json({ error: (e as Error).message }, { status: 500 });
  }
});
