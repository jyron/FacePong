#!/usr/bin/env python3
"""Set every FacePong IAP available in ALL territories so it can sell worldwide,
then print final states (target: READY_TO_SUBMIT)."""
import sys, os, json, time
sys.path.insert(0, os.path.expanduser("~/.appstoreconnect"))
import asc

APP = "6779310642"


def all_iaps():
    d = asc.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2?limit=200&fields[inAppPurchases]=productId,state")
    return [(x["id"], x["attributes"]["productId"], x["attributes"].get("state")) for x in d.get("data", [])]


def all_territories():
    ids, url = [], "/v1/territories?limit=200"
    while url:
        d = asc.call("GET", url)
        ids += [t["id"] for t in d.get("data", [])]
        url = (d.get("links", {}) or {}).get("next")
        if url:
            url = url.replace(asc.BASE, "")
    return ids


def main():
    terr = all_territories()
    print(f"territories: {len(terr)}")
    terr_data = [{"type": "territories", "id": t} for t in terr]
    for iap_id, pid, state in all_iaps():
        # remove any existing (e.g. USA-only) availability, then recreate for all territories
        cur = asc.call("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseAvailability")
        if "httpError" not in cur and cur.get("data"):
            av_id = cur["data"]["id"]
            asc.call("DELETE", f"/v1/inAppPurchaseAvailabilities/{av_id}")
        body = {"data": {"type": "inAppPurchaseAvailabilities",
                         "attributes": {"availableInNewTerritories": True},
                         "relationships": {
                             "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                             "availableTerritories": {"data": terr_data}}}}
        r = asc.call("POST", "/v1/inAppPurchaseAvailabilities", body)
        ok = "httpError" not in r
        print(f"  {pid}: availability {'OK' if ok else 'FAIL ' + json.dumps(r.get('body'))[:200]}")
        time.sleep(0.3)

    print("\n=== final states ===")
    for _, pid, _ in all_iaps():
        pass
    for iap_id, pid, state in all_iaps():
        print(f"  {pid}: {state}")


if __name__ == "__main__":
    main()
