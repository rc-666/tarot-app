import { test } from "node:test";
import assert from "node:assert/strict";
import * as A from "astronomy-engine";
import {
  decanCard, decanOf, signOf, moonLon, planetLon, moodShifts, localToUtc, localParts,
  aspectBetween, strongestTransit, dailyCards, natalPoints, SIGN_CARD, PLANET_CARD,
  SIGNS, PLANETS, signMidpoint, SUPPORTED_TZ,
} from "../_shared/sky.ts";

test("decan cards follow Golden Dawn order", () => {
  assert.equal(decanCard(0).id, "w02");      // Aries I
  assert.equal(decanCard(10).id, "c03");      // Cancer II (design example: Moon mid-Cancer -> Three of Cups)
  assert.equal(decanCard(12).id, "w05");     // Leo I
  assert.equal(decanCard(27).id, "p02"); // Capricorn I
  assert.equal(decanCard(30).id, "s05");    // Aquarius I
  assert.equal(decanCard(35).id, "c10");      // Pisces III
  const ids = new Set(Array.from({ length: 36 }, (_, i) => decanCard(i).id));
  assert.equal(ids.size, 36, "each minor 2-10 of each suit used exactly once");
});

test("design example: Moon in Cancer -> The Chariot", () => {
  assert.equal(SIGN_CARD[signOf(100)], "m07");
  assert.equal(decanOf(359.99), 35);
  assert.equal(decanOf(-0.5), 35);
});

test("Sun position matches a known value (J2000 epoch ~280.37°)", () => {
  const lon = planetLon("sun", new Date("2000-01-01T12:00:00Z"));
  assert.ok(Math.abs(lon - 280.37) < 0.1, `sun ${lon}`);
  assert.equal(signOf(planetLon("sun", new Date("2026-11-30T12:00:00Z"))), "sagittarius");
  assert.equal(signOf(planetLon("sun", new Date("2026-08-14T12:00:00Z"))), "leo");
});

test("Moon and Sun share longitude at new moon", () => {
  const nm = A.SearchMoonPhase(0, A.MakeTime(new Date("2026-11-01T00:00:00Z")), 40)!;
  const diff = Math.abs(((moonLon(nm.date) - planetLon("sun", nm.date) + 540) % 360) - 180);
  assert.ok(diff < 0.05, `diff ${diff}`);
});

test("mood shifts: one per decan, about every 18 h", () => {
  const from = new Date("2026-11-22T00:00:00Z");
  const to = new Date("2026-12-22T00:00:00Z");
  const s = moodShifts(from, to);
  assert.ok(s.length >= 37 && s.length <= 42, `count ${s.length}`);
  for (let i = 0; i < s.length; i++) {
    const lon = moonLon(new Date(s[i].at));
    const off = Math.abs(((lon - s[i].decan * 10 + 540) % 360) - 180);
    assert.ok(off < 0.02, `shift ${i} off by ${off}`);
    if (i > 0) {
      assert.equal(s[i].decan, (s[i - 1].decan + 1) % 36);
      const gapH = (Date.parse(s[i].at) - Date.parse(s[i - 1].at)) / 3.6e6;
      assert.ok(gapH > 14 && gapH < 24, `gap ${gapH}`);
    }
    assert.ok(Date.parse(s[i].at) >= from.getTime() && Date.parse(s[i].at) < to.getTime());
  }
});

test("06:00 local in Brazil and Mexico time zones", () => {
  const cases: [string, string][] = [
    ["America/Noronha", "2026-11-22T08:00:00.000Z"],
    ["America/Sao_Paulo", "2026-11-22T09:00:00.000Z"],
    ["America/Manaus", "2026-11-22T10:00:00.000Z"],
    ["America/Rio_Branco", "2026-11-22T11:00:00.000Z"],
    ["America/Mexico_City", "2026-11-22T12:00:00.000Z"],
  ];
  for (const [tz, iso] of cases) assert.equal(localToUtc("2026-11-22", 6, 0, tz).toISOString(), iso, tz);
  // DST zone sanity: New York in July is UTC-4
  assert.equal(localToUtc("2026-07-01", 6, 0, "America/New_York").toISOString(), "2026-07-01T10:00:00.000Z");
  assert.deepEqual(localParts(new Date("2026-11-22T02:30:00Z"), "America/Sao_Paulo"), { day: "2026-11-21", hour: 23 });
  for (const tz of SUPPORTED_TZ) assert.ok(localToUtc("2026-11-22", 6, 0, tz) instanceof Date);
});

test("aspects and orbs", () => {
  assert.equal(aspectBetween(10, 10)!.aspect, "conjunction");
  assert.equal(aspectBetween(10, 190)!.aspect, "opposition");
  assert.equal(aspectBetween(355, 85)!.aspect, "square");
  assert.equal(aspectBetween(0, 125)!.aspect, "trine");
  assert.equal(aspectBetween(0, 64)!.aspect, "sextile");
  assert.equal(aspectBetween(0, 66), null);
  assert.equal(aspectBetween(0, 45), null);
});

test("influence rule: upright/reversed and fallback", () => {
  const t = new Date("2026-11-22T09:00:00Z");
  for (const s of SIGNS) {
    const inf = strongestTransit(t, { sun: signMidpoint(s) }, s);
    assert.ok(Object.values(PLANET_CARD).includes(inf.card) || inf.card === "m02");
    if (inf.aspect === "trine" || inf.aspect === "sextile") assert.equal(inf.reversed, false);
    if (inf.aspect === "square" || inf.aspect === "opposition") assert.equal(inf.reversed, true);
    if (inf.aspect === null) assert.equal(inf.reversed, false);
  }
  // Exact conjunction with Mars must be reversed, with Venus upright
  const mars = planetLon("mars", t), venus = planetLon("venus", t);
  const m = strongestTransit(t, { sun: mars }, "aries");
  if (m.planet === "mars") { assert.equal(m.aspect, "conjunction"); assert.equal(m.reversed, true); }
  const v = strongestTransit(t, { sun: venus }, "libra");
  if (v.planet === "venus") { assert.equal(v.reversed, false); }
});

test("daily cards are deterministic and use the 06:00 local moment", () => {
  const a = dailyCards("2026-11-22", "America/Sao_Paulo", "leo");
  const b = dailyCards("2026-11-22", "America/Sao_Paulo", "leo");
  assert.deepEqual(a, b);
  assert.equal(a.at, "2026-11-22T09:00:00.000Z");
  assert.equal(a.advice.card, SIGN_CARD[a.advice.moonSign]);
});

test("natal points: Moon only with birth time", () => {
  const n1 = natalPoints("1972-08-14", null, null);
  assert.equal(signOf(n1.sun), "leo");
  assert.equal(n1.moon, undefined);
  const n2 = natalPoints("1972-08-14", "08:30", "America/Sao_Paulo");
  assert.ok(typeof n2.moon === "number");
});

test("all planets resolve", () => {
  for (const p of PLANETS) { const l = planetLon(p, new Date()); assert.ok(l >= 0 && l < 360); }
});
