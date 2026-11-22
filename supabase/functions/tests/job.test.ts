import { test } from "node:test";
import assert from "node:assert/strict";
import { runSkyJob, jobDays, type Db, type ProfileRow } from "../_shared/job.ts";
import { SUPPORTED_TZ } from "../_shared/sky.ts";

function fakeDb(profiles: ProfileRow[]) {
  const tables: Record<string, Map<string, Record<string, unknown>>> = {};
  const natal: Record<string, [number, number | null, string]> = {};
  const db: Db = {
    async upsert(table, rows, onConflict) {
      const t = (tables[table] ??= new Map());
      for (const r of rows) t.set(onConflict.split(",").map((k) => String(r[k])).join("|"), r);
    },
    async profilesPage(afterId, limit) {
      return profiles.filter((p) => afterId === null || p.id > afterId).sort((a, b) => (a.id < b.id ? -1 : 1)).slice(0, limit);
    },
    async setNatal(id, sun, moon, sign) { natal[id] = [sun, moon, sign]; },
    async deleteBefore() {},
  };
  return { db, tables, natal };
}

const base = { tz: "America/Sao_Paulo", birth_time: null, birth_tz: null, natal_sun: null, natal_moon: null };

test("job fills daily cards, mood shifts and personal cards; idempotent", async () => {
  const profiles: ProfileRow[] = Array.from({ length: 7 }, (_, i) => ({
    ...base, id: `u${i}`, sun_sign: "leo", birth_date: "1972-08-14",
  }));
  profiles[1] = { ...profiles[1], birth_time: "08:30", birth_tz: "America/Sao_Paulo" };
  profiles[2] = { ...profiles[2], tz: "Not/AZone" };
  const { db, tables, natal } = fakeDb(profiles);
  const now = new Date("2026-11-22T05:00:00Z");
  const r = await runSkyJob(db, now, { pageSize: 3 }); // forces 3 pages
  assert.equal(r.daily, SUPPORTED_TZ.length * 2 * 12);
  assert.equal(r.personal, 14);
  assert.equal(r.natal, 7);
  assert.deepEqual(r.errors, []);
  assert.ok(r.shifts >= 10 && r.shifts <= 14, `shifts ${r.shifts}`);
  assert.equal(natal.u0[1], null, "no birth time -> no natal moon");
  assert.equal(typeof natal.u1[1], "number");
  assert.equal(natal.u0[2], "leo");
  const before = tables.daily_cards.size;
  await runSkyJob(db, now, { pageSize: 3 });
  assert.equal(tables.daily_cards.size, before, "second run upserts, no duplicates");
});

test("job days: Mexico is still on the previous day at 05:00 UTC", () => {
  const now = new Date("2026-11-22T05:00:00Z");
  assert.deepEqual(jobDays(now, "America/Sao_Paulo"), ["2026-11-22", "2026-11-23"]);
  assert.deepEqual(jobDays(now, "America/Mexico_City"), ["2026-11-21", "2026-11-22"]);
  assert.deepEqual(jobDays(new Date("2026-12-31T05:00:00Z"), "America/Noronha"), ["2026-12-31", "2027-01-01"]);
});
