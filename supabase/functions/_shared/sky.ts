// Sky engine for the tarot app.
// Pure functions: planet positions -> Golden Dawn tarot cards.
// Uses Astronomy Engine (MIT licence). Tropical zodiac, true ecliptic of date.
import * as A from "astronomy-engine";

// ---------- Correspondences ----------

export const SIGNS = [
  "aries", "taurus", "gemini", "cancer", "leo", "virgo",
  "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
] as const;
export type Sign = typeof SIGNS[number];

/** Major arcana card id for each sign (Golden Dawn). */
export const SIGN_CARD: Record<Sign, string> = {
  aries: "major_04_emperor",
  taurus: "major_05_hierophant",
  gemini: "major_06_lovers",
  cancer: "major_07_chariot",
  leo: "major_08_strength",
  virgo: "major_09_hermit",
  libra: "major_11_justice",
  scorpio: "major_13_death",
  sagittarius: "major_14_temperance",
  capricorn: "major_15_devil",
  aquarius: "major_17_star",
  pisces: "major_18_moon",
};

export const PLANETS = [
  "sun", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto",
] as const;
export type Planet = typeof PLANETS[number];

/** Major arcana card id for each planet (Golden Dawn; modern outer planets). */
export const PLANET_CARD: Record<Planet, string> = {
  sun: "major_19_sun",
  mercury: "major_01_magician",
  venus: "major_03_empress",
  mars: "major_16_tower",
  jupiter: "major_10_wheel",
  saturn: "major_21_world",
  uranus: "major_00_fool",
  neptune: "major_12_hanged_man",
  pluto: "major_20_judgement",
};

/** Traditional ruler, used when no aspect is within orb. */
export const SIGN_RULER: Record<Sign, Planet | "moon"> = {
  aries: "mars", taurus: "venus", gemini: "mercury", cancer: "moon",
  leo: "sun", virgo: "mercury", libra: "venus", scorpio: "mars",
  sagittarius: "jupiter", capricorn: "saturn", aquarius: "saturn", pisces: "jupiter",
};

const ELEMENT_SUIT = ["wands", "pentacles", "swords", "cups"] as const; // fire, earth, air, water

/** Decan index 0..35 (0 = Aries 0-10°). */
export function decanOf(lon: number): number {
  return Math.floor(norm360(lon) / 10) % 36;
}

/** Minor card (2-10) for a decan, Golden Dawn order: cardinal 2-4, fixed 5-7, mutable 8-10. */
export function decanCard(decan: number): { id: string; suit: string; number: number } {
  const sign = Math.floor(decan / 3);
  const third = decan % 3;
  const modality = sign % 3; // 0 cardinal, 1 fixed, 2 mutable
  const suit = ELEMENT_SUIT[sign % 4];
  const number = 2 + modality * 3 + third;
  return { id: `minor_${suit}_${String(number).padStart(2, "0")}`, suit, number };
}

export function signOf(lon: number): Sign {
  return SIGNS[Math.floor(norm360(lon) / 30) % 12];
}

// ---------- Positions ----------

export function norm360(x: number): number {
  return ((x % 360) + 360) % 360;
}

const BODY: Record<Planet, A.Body> = {
  sun: A.Body.Sun, mercury: A.Body.Mercury, venus: A.Body.Venus, mars: A.Body.Mars,
  jupiter: A.Body.Jupiter, saturn: A.Body.Saturn, uranus: A.Body.Uranus,
  neptune: A.Body.Neptune, pluto: A.Body.Pluto,
};

export function moonLon(t: Date): number {
  return norm360(A.EclipticGeoMoon(t).lon);
}

export function planetLon(p: Planet, t: Date): number {
  if (p === "sun") return norm360(A.SunPosition(t).elon);
  return norm360(A.Ecliptic(A.GeoVector(BODY[p], t, true)).elon);
}

// ---------- Transits ----------

export type Aspect = "conjunction" | "sextile" | "square" | "trine" | "opposition";
const ASPECTS: { name: Aspect; angle: number; orb: number; weight: number }[] = [
  { name: "conjunction", angle: 0, orb: 8, weight: 1.0 },
  { name: "opposition", angle: 180, orb: 8, weight: 0.9 },
  { name: "square", angle: 90, orb: 7, weight: 0.85 },
  { name: "trine", angle: 120, orb: 7, weight: 0.8 },
  { name: "sextile", angle: 60, orb: 5, weight: 0.6 },
];
const SOFT_CONJ: Planet[] = ["sun", "mercury", "venus", "jupiter"];

export interface Influence {
  planet: Planet | "moon"; // "moon" only as Cancer's ruler fallback
  card: string;
  reversed: boolean;
  aspect: Aspect | null; // null = fallback to ruler
  orb: number | null;
  target: "sun" | "moon";
}

export function aspectBetween(a: number, b: number) {
  const sep = Math.abs(((a - b + 540) % 360) - 180); // 0..180
  let best: { aspect: Aspect; orb: number; score: number } | null = null;
  for (const asp of ASPECTS) {
    const orb = Math.abs(sep - asp.angle);
    if (orb <= asp.orb) {
      const score = asp.weight * (1 - orb / asp.orb);
      if (!best || score > best.score) best = { aspect: asp.name, orb, score };
    }
  }
  return best;
}

function isReversed(p: Planet, aspect: Aspect): boolean {
  if (aspect === "trine" || aspect === "sextile") return false;
  if (aspect === "square" || aspect === "opposition") return true;
  return !SOFT_CONJ.includes(p);
}

/**
 * Strongest transit to her point(s).
 * targets.sun: natal Sun longitude, or her sign's midpoint (e.g. Leo = 135) when we only know the sign.
 * targets.moon: natal Moon longitude, only when birth time is known.
 */
export function strongestTransit(
  t: Date,
  targets: { sun: number; moon?: number },
  fallbackSign: Sign,
): Influence {
  let best: (Influence & { score: number }) | null = null;
  for (const p of PLANETS) {
    const lon = planetLon(p, t);
    for (const target of ["sun", "moon"] as const) {
      const point = targets[target];
      if (point === undefined) continue;
      const a = aspectBetween(lon, point);
      if (!a) continue;
      if (!best || a.score > best.score) {
        best = {
          planet: p, card: PLANET_CARD[p], reversed: isReversed(p, a.aspect),
          aspect: a.aspect, orb: round2(a.orb), target, score: a.score,
        };
      }
    }
  }
  if (best) {
    const { score: _s, ...rest } = best;
    return rest;
  }
  const ruler = SIGN_RULER[fallbackSign];
  const card = ruler === "moon" ? "major_02_high_priestess" : PLANET_CARD[ruler];
  return { planet: ruler, card, reversed: false, aspect: null, orb: null, target: "sun" };
}

export function signMidpoint(s: Sign): number {
  return SIGNS.indexOf(s) * 30 + 15;
}

// ---------- Daily cards ----------

export interface DailyCards {
  day: string; // YYYY-MM-DD local
  tz: string;
  at: string; // ISO UTC of the 06:00 local reference moment
  influence: Influence;
  advice: { card: string; moonSign: Sign };
}

export const REFERENCE_HOUR = 6;

export function dailyCards(
  day: string,
  tz: string,
  sign: Sign,
  natal?: { sun: number; moon?: number },
): DailyCards {
  const at = localToUtc(day, REFERENCE_HOUR, 0, tz);
  const influence = strongestTransit(at, natal ?? { sun: signMidpoint(sign) }, sign);
  const ms = signOf(moonLon(at));
  return { day, tz, at: at.toISOString(), influence, advice: { card: SIGN_CARD[ms], moonSign: ms } };
}

// ---------- Mood shifts (Moon decan ingresses) ----------

export interface MoodShift { at: string; decan: number; card: string; moonSign: Sign }

/** Every Moon decan ingress in [from, to). */
export function moodShifts(from: Date, to: Date): MoodShift[] {
  const out: MoodShift[] = [];
  const stepMs = 2 * 3600 * 1000; // Moon moves < 1.3°/2h, never crosses two 10° boundaries in one step
  let t0 = from;
  let d0 = decanOf(moonLon(t0));
  while (t0 < to) {
    const t1 = new Date(Math.min(t0.getTime() + stepMs, to.getTime()));
    const d1 = decanOf(moonLon(t1));
    if (d1 !== d0) {
      const boundary = d1 * 10;
      const f = (time: A.AstroTime) => {
        const diff = ((moonLon(time.date) - boundary + 540) % 360) - 180;
        return diff;
      };
      const hit = A.Search(f, A.MakeTime(t0), A.MakeTime(t1), { dtToleranceSeconds: 1 });
      if (hit && hit.date < to) {
        out.push({ at: new Date(Math.round(hit.date.getTime() / 1000) * 1000).toISOString(), decan: d1, card: decanCard(d1).id, moonSign: SIGNS[Math.floor(d1 / 3)] });
      }
    }
    t0 = t1;
    d0 = d1;
  }
  return out;
}

/** Mood card in force at time t. */
export function moodAt(t: Date): { decan: number; card: string; moonSign: Sign } {
  const d = decanOf(moonLon(t));
  return { decan: d, card: decanCard(d).id, moonSign: SIGNS[Math.floor(d / 3)] };
}

// ---------- Notification planning ----------

export const QUIET_START = 21; // 21:00 local
export const QUIET_END = 8; // 08:00 local

/** Pick which mood shifts get a notification: outside quiet hours, max one per local day (the first). */
export function notifiableShifts(shifts: MoodShift[], tz: string): MoodShift[] {
  const seen = new Set<string>();
  const out: MoodShift[] = [];
  for (const s of shifts) {
    const { day, hour } = localParts(new Date(s.at), tz);
    if (hour >= QUIET_START || hour < QUIET_END) continue;
    if (seen.has(day)) continue;
    seen.add(day);
    out.push(s);
  }
  return out;
}

// ---------- Time zones ----------

function tzOffsetMs(t: Date, tz: string): number {
  const f = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
  });
  const p = Object.fromEntries(f.formatToParts(t).map((x) => [x.type, x.value]));
  const asUtc = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
  return asUtc - Math.floor(t.getTime() / 1000) * 1000;
}

/** UTC instant of a local wall-clock time in tz. */
export function localToUtc(day: string, hour: number, minute: number, tz: string): Date {
  const [y, m, d] = day.split("-").map(Number);
  const guess = Date.UTC(y, m - 1, d, hour, minute);
  let t = guess - tzOffsetMs(new Date(guess), tz);
  t = guess - tzOffsetMs(new Date(t), tz); // second pass for DST edges
  return new Date(t);
}

export function localParts(t: Date, tz: string): { day: string; hour: number } {
  const f = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit",
  });
  const p = Object.fromEntries(f.formatToParts(t).map((x) => [x.type, x.value]));
  return { day: `${p.year}-${p.month}-${p.day}`, hour: +p.hour };
}

// ---------- Natal points ----------

/**
 * Natal Sun (always) and Moon (only with birth time). Without a time, the Sun is taken at local noon
 * (error < 0.5°).
 */
export function natalPoints(birthDate: string, birthTime: string | null, birthTz: string | null): { sun: number; moon?: number } {
  const tz = birthTz ?? "UTC";
  const [hh, mm] = birthTime ? birthTime.split(":").map(Number) : [12, 0];
  const t = localToUtc(birthDate, hh, mm, tz);
  const sun = planetLon("sun", t);
  return birthTime && birthTz ? { sun: round2(sun), moon: round2(moonLon(t)) } : { sun: round2(sun) };
}

function round2(x: number) {
  return Math.round(x * 100) / 100;
}

/** Time zones the cron computes sign-level cards for. Add more when launching new markets. */
export const SUPPORTED_TZ = [
  "America/Noronha", "America/Sao_Paulo", "America/Manaus", "America/Rio_Branco",
  "America/Mexico_City", "America/Cancun", "America/Tijuana",
];
