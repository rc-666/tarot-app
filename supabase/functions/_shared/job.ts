// Daily sky job, independent of Supabase so it can be tested with a fake database.
import {
  dailyCards, localParts, moodShifts, natalPoints, signOf, SIGNS, SUPPORTED_TZ, type Sign,
} from "./sky.ts";

export interface ProfileRow {
  id: string;
  sun_sign: Sign;
  tz: string;
  birth_date: string;
  birth_time: string | null;
  birth_tz: string | null;
  natal_sun: number | null;
  natal_moon: number | null;
}

export interface Db {
  upsert(table: string, rows: Record<string, unknown>[], onConflict: string): Promise<void>;
  /** Profiles ordered by id, starting after `afterId`. */
  profilesPage(afterId: string | null, limit: number): Promise<ProfileRow[]>;
  /** Also corrects sun_sign: the phone picks it from a date table, the engine is exact on cusp days. */
  setNatal(id: string, sun: number, moon: number | null, sunSign: Sign): Promise<void>;
  deleteBefore(table: string, column: string, value: string): Promise<void>;
}

const DAY_MS = 86400000;

function addDays(day: string, n: number): string {
  const [y, m, d] = day.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d) + n * DAY_MS).toISOString().slice(0, 10);
}

/** Local "today" and "tomorrow" for a zone at instant `now`. */
export function jobDays(now: Date, tz: string): string[] {
  const today = localParts(now, tz).day;
  return [today, addDays(today, 1)];
}

function cardRow(c: ReturnType<typeof dailyCards>) {
  return {
    influence_planet: c.influence.planet,
    influence_card: c.influence.card,
    influence_reversed: c.influence.reversed,
    influence_aspect: c.influence.aspect,
    advice_card: c.advice.card,
    moon_sign: c.advice.moonSign,
    computed_at: new Date().toISOString(),
  };
}

export interface JobResult { daily: number; personal: number; natal: number; shifts: number; errors: string[] }

export async function runSkyJob(db: Db, now: Date, opts: { pageSize?: number } = {}): Promise<JobResult> {
  const result: JobResult = { daily: 0, personal: 0, natal: 0, shifts: 0, errors: [] };

  // 1. Sign-level cards for every supported zone, today + tomorrow.
  const daily: Record<string, unknown>[] = [];
  for (const tz of SUPPORTED_TZ) {
    for (const day of jobDays(now, tz)) {
      for (const sign of SIGNS) daily.push({ day, tz, sign, ...cardRow(dailyCards(day, tz, sign)) });
    }
  }
  await db.upsert("daily_cards", daily, "day,tz,sign");
  result.daily = daily.length;

  // 2. Mood shifts from yesterday to 8 days ahead (the phone schedules notifications from these).
  const shifts = moodShifts(new Date(now.getTime() - DAY_MS), new Date(now.getTime() + 8 * DAY_MS));
  await db.upsert("mood_shifts", shifts.map((s) => ({ at: s.at, decan: s.decan, card: s.card, moon_sign: s.moonSign })), "at");
  result.shifts = shifts.length;

  // 3. Personal cards, paged.
  const pageSize = opts.pageSize ?? 500;
  let after: string | null = null;
  for (;;) {
    const page = await db.profilesPage(after, pageSize);
    if (page.length === 0) break;
    const rows: Record<string, unknown>[] = [];
    for (const p of page) {
      try {
        let sun = p.natal_sun;
        let moon = p.natal_moon;
        if (sun === null) {
          const n = natalPoints(p.birth_date, p.birth_time, p.birth_tz);
          sun = n.sun;
          moon = n.moon ?? null;
          await db.setNatal(p.id, sun, moon, signOf(sun));
          result.natal++;
        }
        const sign = signOf(sun);
        const tz = isValidTz(p.tz) ? p.tz : "America/Sao_Paulo";
        for (const day of jobDays(now, tz)) {
          const c = dailyCards(day, tz, sign, moon === null ? { sun } : { sun, moon });
          rows.push({ user_id: p.id, day, ...cardRow(c) });
        }
      } catch (e) {
        result.errors.push(`${p.id}: ${(e as Error).message}`);
      }
    }
    if (rows.length) await db.upsert("user_daily_cards", rows, "user_id,day");
    result.personal += rows.length;
    after = page[page.length - 1].id;
    if (page.length < pageSize) break;
  }

  // 4. Housekeeping.
  const cutoff = new Date(now.getTime() - 30 * DAY_MS).toISOString().slice(0, 10);
  await db.deleteBefore("daily_cards", "day", cutoff);
  await db.deleteBefore("user_daily_cards", "day", cutoff);
  await db.deleteBefore("mood_shifts", "at", new Date(now.getTime() - 3 * DAY_MS).toISOString());

  return result;
}

export function isValidTz(tz: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}
