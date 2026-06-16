#!/usr/bin/env python3
"""Have Nano Banana Pro (Gemini 3 Pro Image) GENERATE a polished image,
guided by reference images (e.g. to keep a face identity consistent).
Usage: gemini_generate.py <out.png> "<prompt>" <ref1.png> [ref2.png ...]
Env: AR=9:16 sets the aspect ratio; IMG_MODEL overrides the model."""
import base64, json, os, subprocess, sys, urllib.request, urllib.error

PROJECT = "bot-trade-497417"
LOCATION = "global"
MODEL = os.environ.get("IMG_MODEL", "gemini-3-pro-image-preview")
ASPECT = os.environ.get("AR", "9:16")


def token():
    return subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()


def generate(out_path, prompt, refs):
    parts = [{"text": prompt}]
    for r in refs:
        parts.append({"inlineData": {"mimeType": "image/png",
                                     "data": base64.b64encode(open(r, "rb").read()).decode()}})
    url = (f"https://aiplatform.googleapis.com/v1/projects/{PROJECT}/locations/"
           f"{LOCATION}/publishers/google/models/{MODEL}:generateContent")
    body = {"contents": [{"role": "user", "parts": parts}],
            "generationConfig": {"responseModalities": ["IMAGE"],
                                 "imageConfig": {"aspectRatio": ASPECT}}}
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
        method="POST")
    try:
        resp = json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode()[:1500]); sys.exit(1)
    for p in resp.get("candidates", [{}])[0].get("content", {}).get("parts", []):
        if "inlineData" in p:
            open(out_path, "wb").write(base64.b64decode(p["inlineData"]["data"]))
            print("WROTE", out_path); return
    print("NO IMAGE:", json.dumps(resp)[:1500]); sys.exit(2)


if __name__ == "__main__":
    generate(sys.argv[1], sys.argv[2], sys.argv[3:])
