#!/usr/bin/env python3
"""Resubmit FacePong 1.0.1 (build 24) bundled WITH all 8 first-time IAPs.
First-time IAPs must ride in the SAME review submission as a version, so:
cancel the version-only submission -> open a new one -> add the version item ->
attach each IAP via inAppPurchaseSubmissions while it's open -> submit together.
Falls back to version-only resubmission if IAP bundling is rejected."""
import sys, os, json, time
sys.path.insert(0, os.path.expanduser("~/.appstoreconnect"))
import asc

APP = "6779310642"
VERSION_ID = "93ec0410-8f80-44a2-81cd-ec729954ce7d"   # 1.0.1
OLD_SUB = "79a7461f-7c41-4e6d-aa8a-27fdb404a77c"


def err(r):
    return json.dumps(r.get("body", r).get("errors", [{}])[0]).replace("\n", " ")[:240]


def iaps():
    d = asc.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?limit=200&fields[inAppPurchases]=productId,state")
    return [(x["id"], x["attributes"]["productId"]) for x in d.get("data", [])]


def main():
    # 1. cancel the version-only submission
    r = asc.call("PATCH", f"/v1/reviewSubmissions/{OLD_SUB}",
                 {"data": {"type": "reviewSubmissions", "id": OLD_SUB, "attributes": {"canceled": True}}})
    print("cancel old submission:", "OK" if "httpError" not in r else err(r))
    time.sleep(3)

    # 2. open a fresh submission
    sub = asc.call("POST", "/v1/reviewSubmissions",
                   {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                             "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    if "httpError" in sub:
        print("create submission FAILED:", err(sub)); sys.exit(1)
    sub_id = sub["data"]["id"]
    print("new review submission:", sub_id)

    # 3. add the app version item
    r = asc.call("POST", "/v1/reviewSubmissionItems",
                 {"data": {"type": "reviewSubmissionItems", "relationships": {
                     "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                     "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION_ID}}}}})
    print("add version item:", "OK" if "httpError" not in r else err(r))

    # 4. attach each IAP via inAppPurchaseSubmissions while the submission is OPEN
    iap_ok = 0
    for iid, pid in iaps():
        r = asc.call("POST", "/v1/inAppPurchaseSubmissions",
                     {"data": {"type": "inAppPurchaseSubmissions",
                               "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
        ok = "httpError" not in r
        iap_ok += ok
        print(f"  IAP {pid}:", "OK" if ok else err(r))

    # 5. submit the whole thing
    r = asc.call("PATCH", f"/v1/reviewSubmissions/{sub_id}",
                 {"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}})
    if "httpError" in r:
        print("SUBMIT FAILED:", err(r))
    else:
        print(f"SUBMITTED ✓  IAPs attached: {iap_ok}/8  state:", r.get("data", {}).get("attributes", {}).get("state"))

    print("\n=== IAP states ===")
    for iid, pid in iaps():
        s = asc.call("GET", f"/v2/inAppPurchases/{iid}?fields[inAppPurchases]=state")
        print(f"  {pid}: {s['data']['attributes'].get('state')}")


if __name__ == "__main__":
    main()
