#!/usr/bin/env python3
"""Submit FacePong 1.0.1 (build 24) + all 8 IAPs to App Store review in one
review submission. Waits for the build to finish processing first."""
import sys, os, json, time
sys.path.insert(0, os.path.expanduser("~/.appstoreconnect"))
import asc

APP = "6779310642"
VERSION_ID = "93ec0410-8f80-44a2-81cd-ec729954ce7d"   # 1.0.1
BUILD_NUMBER = "24"


def find_build():
    d = asc.call("GET", f"/v1/apps/{APP}/builds?limit=50&fields[builds]=version,processingState")
    for b in d.get("data", []):
        if str(b["attributes"].get("version")) == BUILD_NUMBER:
            return b["id"], b["attributes"].get("processingState")
    return None, None


def wait_valid():
    for i in range(60):
        bid, state = find_build()
        print(f"  build {BUILD_NUMBER}: {state or 'not-listed'}")
        if state == "VALID":
            return bid
        time.sleep(30)
    return None


def iap_ids():
    d = asc.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?limit=200&fields[inAppPurchases]=productId,state")
    return [(x["id"], x["attributes"]["productId"], x["attributes"].get("state")) for x in d.get("data", [])]


def main():
    print("Waiting for build 24 to validate…")
    bid = wait_valid()
    if not bid:
        print("BUILD NOT VALID — aborting; re-run later."); sys.exit(1)
    print(f"build id: {bid}")

    r = asc.call("PATCH", f"/v1/appStoreVersions/{VERSION_ID}/relationships/build",
                 {"data": {"type": "builds", "id": bid}})
    print("attach build:", "OK" if "httpError" not in r else json.dumps(r["body"])[:300])

    # Create the review submission (reuse an open one if it already exists).
    sub = asc.call("POST", "/v1/reviewSubmissions",
                   {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                             "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    if "httpError" in sub:
        print("create submission err:", json.dumps(sub["body"])[:300])
        existing = asc.call("GET", f"/v1/apps/{APP}/reviewSubmissions?filter[state]=READY_FOR_REVIEW,UNRESOLVED_ISSUES,COMPLETING")
        if existing.get("data"):
            sub_id = existing["data"][0]["id"]
            print("reusing open submission:", sub_id)
        else:
            print("no reusable submission — aborting"); sys.exit(1)
    else:
        sub_id = sub["data"]["id"]
        print("review submission:", sub_id)

    def add_item(rel):
        body = {"data": {"type": "reviewSubmissionItems", "relationships": dict(
            {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}}}, **rel)}}
        return asc.call("POST", "/v1/reviewSubmissionItems", body)

    r = add_item({"appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION_ID}}})
    print("add version item:", "OK" if "httpError" not in r else json.dumps(r["body"])[:300])

    for iid, pid, state in iap_ids():
        r = add_item({"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}})
        print(f"add IAP {pid} ({state}):", "OK" if "httpError" not in r else json.dumps(r["body"])[:200])

    # Submit.
    r = asc.call("PATCH", f"/v1/reviewSubmissions/{sub_id}",
                 {"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}})
    if "httpError" in r:
        print("SUBMIT FAILED:", json.dumps(r["body"])[:600])
    else:
        print("SUBMITTED ✓ state:", r.get("data", {}).get("attributes", {}).get("state"))


if __name__ == "__main__":
    main()
