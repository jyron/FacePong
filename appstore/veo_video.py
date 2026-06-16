#!/usr/bin/env python3
"""Generate a short promo video with Veo on Vertex AI (image-to-video).
Usage: veo_video.py <seed_image.png> <out.mp4> "<prompt>"
Env: VEO_MODEL (default veo-3.1-generate-001 — latest Veo, native audio + 4K),
DURATION (default 8)."""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.error

PROJECT = "bot-trade-497417"
LOCATION = "us-central1"
MODEL = os.environ.get("VEO_MODEL", "veo-3.1-generate-001")
DURATION = int(os.environ.get("DURATION", "8"))
BASE = f"https://{LOCATION}-aiplatform.googleapis.com/v1/projects/{PROJECT}/locations/{LOCATION}/publishers/google/models/{MODEL}"


def token():
    return subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()


def post(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}, method="POST")
    try:
        return json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode()[:1200]); sys.exit(1)


def main(seed, out, prompt):
    img = base64.b64encode(open(seed, "rb").read()).decode()
    op = post(f"{BASE}:predictLongRunning", {
        "instances": [{"prompt": prompt, "image": {"bytesBase64Encoded": img, "mimeType": "image/png"}}],
        "parameters": {"aspectRatio": "9:16", "durationSeconds": DURATION, "sampleCount": 1},
    })
    name = op.get("name")
    if not name:
        print("no op name:", json.dumps(op)[:800]); sys.exit(1)
    print("operation:", name)
    for _ in range(60):  # poll up to ~9 min
        time.sleep(9)
        res = post(f"{BASE}:fetchPredictOperation", {"operationName": name})
        if res.get("done"):
            videos = (res.get("response", {}).get("videos")
                      or res.get("response", {}).get("generatedSamples") or [])
            if not videos:
                print("done, no video:", json.dumps(res)[:1500]); sys.exit(2)
            v = videos[0]
            b64 = v.get("bytesBase64Encoded") or v.get("video", {}).get("bytesBase64Encoded")
            if b64:
                open(out, "wb").write(base64.b64decode(b64)); print("WROTE", out); return
            print("no inline bytes:", json.dumps(v)[:800]); sys.exit(2)
        print("…still rendering")
    print("timed out"); sys.exit(3)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
