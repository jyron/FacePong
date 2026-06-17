#!/usr/bin/env python3
"""Create FacePong's 8 in-app purchases in App Store Connect via the API:
create IAP -> localization -> USA price schedule -> review screenshot -> (Ready to Submit).
Idempotent on productId (skips create if it already exists; still fills missing pieces)."""
import sys, os, json, time, hashlib, urllib.request, urllib.error
sys.path.insert(0, os.path.expanduser("~/.appstoreconnect"))
import asc  # noqa: E402  (gives us asc.call + asc.token)

APP = "6779310642"
UNLOCK_SHOT = "/tmp/fpshots/m3-paywall-unlock.png"
REFILL_SHOT = "/tmp/fpshots/m6-paywall-refill.png"

# (productId, type, referenceName, displayName<=30, description<=45, priceUSD, screenshot)
PRODUCTS = [
    ("com.facepong.unlock.interesting", "NON_CONSUMABLE", "Unlock Most Interesting Man", "Most Interesting Man", "Permanently unlock this rival.", "1.99", UNLOCK_SHOT),
    ("com.facepong.unlock.wrestler",    "NON_CONSUMABLE", "Unlock The Wrestler",         "The Wrestler",         "Permanently unlock this rival.", "1.99", UNLOCK_SHOT),
    ("com.facepong.unlock.champ",       "NON_CONSUMABLE", "Unlock The Champ",            "The Champ",            "Permanently unlock this rival.", "1.99", UNLOCK_SHOT),
    ("com.facepong.unlock.dictator",    "NON_CONSUMABLE", "Unlock The Dictator",         "The Dictator",         "Permanently unlock this rival.", "2.99", UNLOCK_SHOT),
    ("com.facepong.unlock.president",   "NON_CONSUMABLE", "Unlock The President",        "The President",        "Permanently unlock this rival.", "2.99", UNLOCK_SHOT),
    ("com.facepong.unlock.chairman",    "NON_CONSUMABLE", "Unlock The Chairman",         "The Chairman",         "Permanently unlock this rival.", "2.99", UNLOCK_SHOT),
    ("com.facepong.unlock.all",         "NON_CONSUMABLE", "Unlock All Rivals",           "Unlock Everything",    "All rivals + unlimited hearts.", "9.99", UNLOCK_SHOT),
    ("com.facepong.hearts.refill5",     "CONSUMABLE",     "Refill Hearts",               "Refill Hearts",        "Refill your hearts to full.",    "0.99", REFILL_SHOT),
]


def existing_iaps():
    out = {}
    d = asc.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?limit=200&fields[inAppPurchases]=productId,state")
    for x in d.get("data", []):
        out[x["attributes"]["productId"]] = {"id": x["id"], "state": x["attributes"].get("state")}
    return out


def create_iap(pid, ptype, refname):
    body = {"data": {"type": "inAppPurchases", "attributes": {
        "name": refname, "productId": pid, "inAppPurchaseType": ptype,
        "reviewNote": "Unlocks a CPU opponent / refills the hearts energy used to retry matches. Tap the corresponding button on the paywall shown in the review screenshot.",
    }, "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}}
    r = asc.call("POST", "/v2/inAppPurchases", body)
    if "httpError" in r:
        raise RuntimeError(f"create {pid}: {json.dumps(r['body'])[:400]}")
    return r["data"]["id"]


def has_localization(iap_id):
    d = asc.call("GET", f"/v1/inAppPurchasesV2/{iap_id}/iapPriceSchedule")  # cheap existence probe not reliable; use localizations
    d = asc.call("GET", f"/v1/inAppPurchasesV2/{iap_id}/inAppPurchaseLocalizations?limit=10")
    return len(d.get("data", [])) > 0


def add_localization(iap_id, name, desc):
    body = {"data": {"type": "inAppPurchaseLocalizations", "attributes": {
        "locale": "en-US", "name": name, "description": desc},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}}
    r = asc.call("POST", "/v1/inAppPurchaseLocalizations", body)
    if "httpError" in r:
        return f"loc FAIL: {json.dumps(r['body'])[:300]}"
    return "loc OK"


def has_price(iap_id):
    d = asc.call("GET", f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule")
    return "httpError" not in d and bool(d.get("data"))


def price_point_id(iap_id, price):
    # Page through USA price points to find the one matching the customer price.
    url = f"/v2/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200"
    while url:
        d = asc.call("GET", url)
        if "httpError" in d:
            return None, json.dumps(d["body"])[:300]
        for pp in d.get("data", []):
            if pp["attributes"].get("customerPrice") == price:
                return pp["id"], None
        url = (d.get("links", {}) or {}).get("next")
        if url:
            url = url.replace(asc.BASE, "")
    return None, f"no price point == {price}"


def add_price(iap_id, price):
    ppid, err = price_point_id(iap_id, price)
    if not ppid:
        return f"price FAIL (point): {err}"
    body = {"data": {"type": "inAppPurchasePriceSchedules", "relationships": {
        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
        "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
        "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p}"}]}},
    }, "included": [{"type": "inAppPurchasePrices", "id": "${p}",
        "attributes": {"startDate": None},
        "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": ppid}}}}]}
    r = asc.call("POST", "/v1/inAppPurchasePriceSchedules", body)
    return "price OK" if "httpError" not in r else f"price FAIL: {json.dumps(r['body'])[:300]}"


def has_screenshot(iap_id):
    d = asc.call("GET", f"/v1/inAppPurchasesV2/{iap_id}/appStoreReviewScreenshot")
    return "httpError" not in d and bool(d.get("data"))


def add_screenshot(iap_id, path):
    if not os.path.exists(path):
        return f"shot SKIP: {path} missing"
    data = open(path, "rb").read()
    body = {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots", "attributes": {
        "fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}}
    r = asc.call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", body)
    if "httpError" in r:
        return f"shot reserve FAIL: {json.dumps(r['body'])[:300]}"
    sid = r["data"]["id"]
    op = r["data"]["attributes"]["uploadOperations"][0]
    req = urllib.request.Request(op["url"], data=data, method=op["method"])
    for h in op.get("requestHeaders", []):
        req.add_header(h["name"], h["value"])
    try:
        urllib.request.urlopen(req)
    except urllib.error.HTTPError as e:
        return f"shot PUT FAIL: {e.code} {e.read()[:200]}"
    md5 = hashlib.md5(data).hexdigest()
    patch = {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
        "attributes": {"uploaded": True, "sourceFileChecksum": md5}}}
    r2 = asc.call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{sid}", patch)
    return "shot OK" if "httpError" not in r2 else f"shot commit FAIL: {json.dumps(r2['body'])[:300]}"


def main():
    have = existing_iaps()
    print(f"existing: {len(have)}")
    for pid, ptype, ref, disp, desc, price, shot in PRODUCTS:
        print(f"\n=== {pid} ({price}) ===")
        if pid in have:
            iap_id = have[pid]["id"]
            print(f"  exists id={iap_id} state={have[pid]['state']}")
        else:
            try:
                iap_id = create_iap(pid, ptype, ref)
                print(f"  created id={iap_id}")
            except RuntimeError as e:
                print(f"  CREATE FAILED: {e}")
                continue
        if not has_localization(iap_id):
            print("  " + add_localization(iap_id, disp, desc))
        else:
            print("  loc: already present")
        if not has_price(iap_id):
            print("  " + add_price(iap_id, price))
        else:
            print("  price: already present")
        if not has_screenshot(iap_id):
            print("  " + add_screenshot(iap_id, shot))
        else:
            print("  shot: already present")
        time.sleep(0.4)

    print("\n=== final states ===")
    for pid, info in existing_iaps().items():
        print(f"  {pid}: {info['state']}")


if __name__ == "__main__":
    main()
