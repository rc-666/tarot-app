#!/usr/bin/env python3
"""Build assets/places/places.tsv from GeoNames (CC BY 4.0, attribution required).

Download first (not reachable from the build workspace):
  https://download.geonames.org/export/dump/BR.zip            all Brazilian places
  https://download.geonames.org/export/dump/cities15000.zip   world cities > 15k people
  https://download.geonames.org/export/dump/admin1CodesASCII.txt
  https://download.geonames.org/export/dump/countryInfo.txt
Usage: python3 tool/build_places.py BR.txt cities15000.txt admin1CodesASCII.txt countryInfo.txt
Keeps Brazilian municipalities/cities (feature class P) plus world cities; writes name, region, lat, lon, tz.
"""
import sys, csv

br, world, admin1, countries = sys.argv[1:5]
adm = {}
for line in open(admin1, encoding="utf-8"):
    code, name, *_ = line.rstrip("\n").split("\t")
    adm[code] = name
cty = {}
for line in open(countries, encoding="utf-8"):
    if line.startswith("#"):
        continue
    p = line.rstrip("\n").split("\t")
    cty[p[0]] = p[4]

seen, out = set(), []
def add(p):
    name, lat, lon, cc, a1, tz = p[1], p[4], p[5], p[8], p[10], p[17]
    key = (name, cc, a1)
    if key in seen or not tz:
        return
    seen.add(key)
    region = ", ".join(x for x in (adm.get(f"{cc}.{a1}", ""), cty.get(cc, cc)) if x)
    out.append((name, region, f"{float(lat):.4f}", f"{float(lon):.4f}", tz, int(p[14] or 0)))

for line in open(br, encoding="utf-8"):
    p = line.rstrip("\n").split("\t")
    if p[6] == "P" and p[7] in ("PPLA", "PPLA2", "PPLC", "PPL", "PPLA3") and int(p[14] or 0) >= 1000:
        add(p)
for line in open(world, encoding="utf-8"):
    add(line.rstrip("\n").split("\t"))

out.sort(key=lambda r: -r[5])  # biggest first, so search shows them first
with open("assets/places/places.tsv", "w", encoding="utf-8") as f:
    f.write("# name\tregion\tlat\tlon\ttz  (GeoNames, CC BY 4.0)\n")
    w = csv.writer(f, delimiter="\t", lineterminator="\n")
    for r in out:
        w.writerow(r[:5])
print(len(out), "places")
