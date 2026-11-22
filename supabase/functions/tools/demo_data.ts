// Writes app/assets/demo/sky.json: real cards from the sky engine for the demo build (no backend).
// Run: node tools/demo_data.ts [from YYYY-MM-DD] [days]
import { writeFileSync, mkdirSync } from "node:fs";
import { dailyCards, moodShifts, localToUtc, SIGNS } from "../_shared/sky.ts";

const tz = "America/Sao_Paulo";
const from = process.argv[2] ?? "2026-11-15";
const days = Number(process.argv[3] ?? 230);
const out: { tz: string; from: string; days: number; cards: Record<string, Record<string, unknown[]>>; moodShifts: unknown[] } =
  { tz, from, days, cards: {}, moodShifts: [] };

const start = new Date(from + "T00:00:00Z");
for (let i = 0; i < days; i++) {
  const day = new Date(start.getTime() + i * 86400000).toISOString().slice(0, 10);
  out.cards[day] = {};
  for (const sign of SIGNS) {
    const c = dailyCards(day, tz, sign);
    // compact row: planet, card, reversed, aspect, adviceCard, moonSign
    out.cards[day][sign] = [c.influence.planet, c.influence.card, c.influence.reversed, c.influence.aspect, c.advice.card, c.advice.moonSign];
  }
}
const t0 = localToUtc(from, 0, 0, tz);
const t1 = new Date(t0.getTime() + (days + 1) * 86400000);
out.moodShifts = moodShifts(new Date(t0.getTime() - 86400000), t1).map((s) => [s.at, s.decan, s.card, s.moonSign]);

mkdirSync("../../app/assets/demo", { recursive: true });
writeFileSync("../../app/assets/demo/sky.json", JSON.stringify(out));
console.log(`days ${days}, shifts ${out.moodShifts.length}`);
