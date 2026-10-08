"""Build a redistributable OSM city extract; only this build tool uses the network."""
import argparse
import collections
import datetime
import hashlib
import gzip
import json
import pathlib
import urllib.parse
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "maps"
BBOX = (44.72, 65.34, 44.98, 65.70)  # south, west, north, east
ENDPOINT = "https://overpass-api.de/api/interpreter"
QUERY = """[out:json][timeout:180];
(
 way[highway]({bbox});
 way[building]({bbox});
 way[natural=water]({bbox});
 relation[natural=water]({bbox});
 way[waterway]({bbox});
 way[railway=rail]({bbox});
 way[landuse~\"forest|grass|recreation_ground|cemetery\"]({bbox});
 way[leisure~\"park|garden|pitch\"]({bbox});
 node[place~\"city|suburb|neighbourhood\"]({bbox});
);
out geom;""".format(bbox=",".join(map(str, BBOX)))


def fetch(url, data=None):
    request = urllib.request.Request(url, data=data, headers={
        "User-Agent": "BerikTulga-offline-map-builder/0.1 (local city extract)",
    })
    with urllib.request.urlopen(request, timeout=210) as response:
        result = response.read()
        return gzip.decompress(result) if result.startswith(b'\x1f\x8b') else result


def osm_api_document():
    """One-time small city extract when Overpass is unavailable; cache every cell."""
    cache = ROOT / "artifacts" / "osm-city-cells"
    cache.mkdir(parents=True, exist_ok=True)
    elements = {}
    south, west, north, east = BBOX
    def cell(w, s, e, n, depth=0):
        name = f"{w:.4f}_{s:.4f}_{e:.4f}_{n:.4f}"
        path = cache / (name + ".osm")
        if not path.exists():
            url = f"https://api.openstreetmap.org/api/0.6/map?bbox={w},{s},{e},{n}"
            print(f"Downloading city cell {name}", flush=True)
            try:
                path.write_bytes(fetch(url))
            except urllib.error.HTTPError as error:
                message = error.read().decode(errors="replace")
                if error.code == 400 and "too many nodes" in message.lower() and depth < 3:
                    midw, mids = (w + e) / 2, (s + n) / 2
                    for box in ((w,s,midw,mids),(midw,s,e,mids),(w,mids,midw,n),(midw,mids,e,n)):
                        cell(*box, depth + 1)
                    return
                raise RuntimeError(message[:1000]) from error
        xml = ET.parse(path).getroot()
        for element in xml:
            if element.tag in ("node", "way", "relation"):
                elements[(element.tag, int(element.attrib["id"]))] = element
    for row in range(2):
        for col in range(2):
            cell(west + (east-west)*col/2, south + (north-south)*row/2,
                 west + (east-west)*(col+1)/2, south + (north-south)*(row+1)/2)
    nodes = {id_: {"lon": float(e.attrib["lon"]), "lat": float(e.attrib["lat"])}
             for (kind, id_), e in elements.items() if kind == "node"}
    ways = {id_: [nodes[int(n.attrib["ref"])] for n in e.findall("nd")
                  if int(n.attrib["ref"]) in nodes]
            for (kind, id_), e in elements.items() if kind == "way"}
    output = []
    for (kind, id_), e in elements.items():
        tags = {t.attrib["k"]: t.attrib["v"] for t in e.findall("tag")}
        selected = ((kind == "node" and tags.get("place") in ("city", "suburb", "neighbourhood"))
                    or (kind == "relation" and tags.get("natural") == "water")
                    or (kind == "way" and ("highway" in tags or "building" in tags
                        or tags.get("natural") == "water" or "waterway" in tags
                        or tags.get("railway") == "rail"
                        or tags.get("landuse") in ("forest", "grass", "recreation_ground", "cemetery")
                        or tags.get("leisure") in ("park", "garden", "pitch"))))
        if not selected:
            continue
        entry = {"type": kind, "id": id_, "tags": tags}
        if kind == "node":
            entry.update(nodes[id_])
        elif kind == "way":
            entry["geometry"] = ways[id_]
        else:
            entry["members"] = [{"type": m.attrib["type"], "ref": int(m.attrib["ref"]),
                "role": m.attrib["role"], "geometry": ways.get(int(m.attrib["ref"]), [])}
                for m in e.findall("member") if m.attrib["type"] == "way"]
        output.append(entry)
    return {"elements": output, "osm3s": {}}


def coordinates(geometry):
    return [[round(p["lon"], 6), round(p["lat"], 6)] for p in geometry
            if "lon" in p and "lat" in p]


def rings(parts):
    """Join OSM multipolygon way segments by their shared endpoints."""
    remaining = [p for p in parts if len(p) >= 2]
    closed = []
    while remaining:
        ring = remaining.pop()
        while ring[0] != ring[-1]:
            match = next((i for i, p in enumerate(remaining)
                          if ring[-1] == p[0] or ring[-1] == p[-1]), None)
            if match is None:
                break
            part = remaining.pop(match)
            if ring[-1] == part[-1]:
                part = part[::-1]
            ring.extend(part[1:])
        if len(ring) >= 4 and ring[0] == ring[-1]:
            closed.append(ring)
    return closed


def contains(ring, point):
    x, y = point
    inside = False
    for a, b in zip(ring, ring[1:]):
        if (a[1] > y) != (b[1] > y):
            if x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]:
                inside = not inside
    return inside


def convert(document):
    features = []
    water_members = {m["ref"] for e in document["elements"]
                     if e["type"] == "relation"
                     for m in e.get("members", []) if m.get("type") == "way"}
    for e in document["elements"]:
        tags = e.get("tags", {})
        name = tags.get("name:kk", tags.get("name", tags.get("name:ru", "")))
        props = {"name": name}
        if e["type"] == "node":
            kind = "place"
            geometry = {"type": "Point", "coordinates": [e["lon"], e["lat"]]}
        elif e["type"] == "relation":
            outer = rings([coordinates(m.get("geometry", []))
                           for m in e.get("members", []) if m.get("role") == "outer"])
            inner = rings([coordinates(m.get("geometry", []))
                           for m in e.get("members", []) if m.get("role") == "inner"])
            if not outer:
                continue
            kind = "water"
            geometry = {"type": "MultiPolygon", "coordinates": [
                [o] + [i for i in inner if contains(o, i[0])] for o in outer]}
        else:
            points = coordinates(e.get("geometry", []))
            if len(points) < 2 or e["id"] in water_members:
                continue
            if "highway" in tags:
                kind = "road"
                props["class"] = tags["highway"]
            elif "building" in tags:
                kind = "building"
            elif tags.get("natural") == "water":
                kind = "water"
            elif "waterway" in tags:
                kind = "waterway"
            elif "railway" in tags:
                kind = "rail"
            else:
                kind = "green"
            polygon = kind in ("building", "water", "green")
            if polygon and (points[0] != points[-1] or len(points) < 4):
                continue
            geometry = {"type": "Polygon" if polygon else "LineString",
                        "coordinates": [points] if polygon else points}
        props["kind"] = kind
        features.append({"type": "Feature", "id": f'{e["type"]}/{e["id"]}',
                         "properties": props, "geometry": geometry})
    return {"type": "FeatureCollection", "features": features}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=pathlib.Path, help="Reuse an Overpass response")
    parser.add_argument("--endpoint", default=ENDPOINT)
    parser.add_argument("--get", action="store_true", help="Use a GET query instead of POST")
    parser.add_argument("--osm-api", action="store_true", help="Fallback to cached small OSM API cells")
    args = parser.parse_args()
    if args.osm_api:
        document = osm_api_document()
        raw = json.dumps(document).encode()
        (ROOT / 'artifacts' / 'kyzylorda-overpass.json').write_bytes(raw)
    elif args.input:
        raw = args.input.read_bytes()
    else:
        print("Downloading Kyzylorda OSM geometry…", flush=True)
        payload = urllib.parse.urlencode({"data": QUERY})
        raw = fetch(args.endpoint + "?" + payload) if args.get else fetch(args.endpoint, payload.encode())
        cache = ROOT / "artifacts" / "kyzylorda-overpass.json"
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_bytes(raw)
    document = json.loads(raw)
    if "remark" in document:
        raise RuntimeError(document["remark"])
    data = convert(document)
    counts = collections.Counter(f["properties"]["kind"] for f in data["features"])
    if counts["road"] < 200 or counts["building"] < 500:
        raise RuntimeError(f"Incomplete city extract: {counts}")
    encoded = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode()
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "kyzylorda.geojson").write_bytes(encoded)
    ranges = {0, 256, 1024, 8192}
    ranges.update(ord(c) // 256 * 256 for f in data["features"]
                  for c in f["properties"]["name"])
    font = "Noto Sans Regular"
    font_dir = DEST / "glyphs" / font
    font_dir.mkdir(parents=True, exist_ok=True)
    assets = [{"file": "kyzylorda.geojson", "bytes": len(encoded),
               "sha256": hashlib.sha256(encoded).hexdigest()}]
    for start in sorted(ranges):
        filename = f"{start}-{start + 255}.pbf"
        path = font_dir / filename
        url = f"https://tiles.openfreemap.org/fonts/{urllib.parse.quote(font)}/{filename}"
        if not path.exists() or path.read_bytes().lstrip().startswith(b'<'):
            path.write_bytes(fetch(url))
        glyph = path.read_bytes()
        if not glyph or glyph[0] != 10:
            raise RuntimeError(f"Not a protobuf glyph range: {path}")
        assets.append({"file": f"glyphs/{font}/{filename}", "bytes": len(glyph),
                       "sha256": hashlib.sha256(glyph).hexdigest()})
    metadata = {
        "city": "Қызылорда", "bounds": [BBOX[1], BBOX[0], BBOX[3], BBOX[2]],
        "source": "OpenStreetMap contributors", "license": "ODbL-1.0",
        "copyright_url": "https://www.openstreetmap.org/copyright",
        "downloaded_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "osm_timestamp": document.get("osm3s", {}).get("timestamp_osm_base"),
        "endpoint": "https://api.openstreetmap.org/api/0.6/map" if args.osm_api else args.endpoint,
        "query": f"Map API cells covering {BBOX}" if args.osm_api else QUERY,
        "sha256": hashlib.sha256(encoded).hexdigest(), "features": dict(counts),
        "package_sha256": hashlib.sha256(json.dumps(assets, sort_keys=True).encode()).hexdigest(),
        "glyph_source": "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
        "font": font, "files": assets,
    }
    (DEST / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Bundled {len(data['features'])} features, {len(encoded)/1024/1024:.1f} MiB; {dict(counts)}")


if __name__ == "__main__":
    main()
