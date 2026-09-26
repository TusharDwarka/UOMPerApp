"""Copy one UOMPerApp account's cloud data into another account.

Copies users/<from>/... (timetable, tasks, notes, attendance, settings, bus
routes) into users/<to>/..., and moves group memberships/ownership across.
Nothing is deleted: the source account is left exactly as it was.

Dry run (default) only prints what would be copied. Add --apply to write.

  pip install firebase-admin
  python tools/copy_account_data.py --key C:\\path\\to\\service-account.json \\
      --from lnMMGSLAnTTSBfAfLq378tXeDjE3 --to someone@example.com
  python tools/copy_account_data.py ... --apply

--to accepts a UID or the email of an existing account.
"""
import argparse
import datetime
import sys

import firebase_admin
from firebase_admin import auth, credentials, firestore

PERSONAL_COLLECTIONS = ["class_sessions", "academic_tasks", "notes", "attendance"]


def resolve_uid(value: str) -> tuple[str, str]:
    if "@" in value:
        user = auth.get_user_by_email(value)
    else:
        user = auth.get_user(value)
    return user.uid, user.email or "(no email / guest)"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--key", required=True, help="service account JSON downloaded from the Firebase console")
    ap.add_argument("--from", dest="src", required=True, help="source UID (the old account)")
    ap.add_argument("--to", dest="dst", required=True, help="destination UID or email")
    ap.add_argument("--apply", action="store_true", help="actually write (otherwise dry run)")
    args = ap.parse_args()

    firebase_admin.initialize_app(credentials.Certificate(args.key))
    db = firestore.client()

    src_uid, src_email = resolve_uid(args.src)
    dst_uid, dst_email = resolve_uid(args.dst)
    if src_uid == dst_uid:
        print("Source and destination are the same account - nothing to do.")
        return 1

    print(f"FROM  {src_uid}  {src_email}")
    print(f"TO    {dst_uid}  {dst_email}")
    print("MODE  " + ("APPLY (writing)" if args.apply else "DRY RUN (nothing is written; add --apply)"))
    print()

    src_ref = db.collection("users").document(src_uid)
    dst_ref = db.collection("users").document(dst_uid)
    # Newer than anything on the phone, so the app accepts the copied settings.
    stamp = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=2)).isoformat()

    batch = db.batch()
    pending = 0

    def queue(ref, data, merge=False):
        nonlocal batch, pending
        if not args.apply:
            return
        batch.set(ref, data, merge=merge)
        pending += 1
        if pending >= 400:
            batch.commit()
            batch = db.batch()
            pending = 0

    # 1. Personal records (tombstones are skipped - they are deletions).
    for col in PERSONAL_COLLECTIONS:
        docs = list(src_ref.collection(col).stream())
        live = [d for d in docs if not (d.to_dict() or {}).get("deleted")]
        print(f"{col:<16} {len(live):>4} to copy   ({len(docs) - len(live)} deleted entries skipped)")
        for d in live:
            queue(dst_ref.collection(col).document(d.id), d.to_dict())

    # 2. Settings (course, semester, folders) and bus routes.
    for name in ["app_settings", "bus_timetable"]:
        snap = src_ref.collection("settings").document(name).get()
        if snap.exists:
            data = snap.to_dict()
            data["updatedAt"] = stamp
            print(f"settings/{name:<14} copy" + (f"  (course: {data.get('courseName')})" if name == "app_settings" else ""))
            queue(dst_ref.collection("settings").document(name), data)
        else:
            print(f"settings/{name:<14} (none)")

    # 3. Groups: add the new account as a member with the same role, and hand
    #    over ownership of groups the old account created.
    src_profile = src_ref.get().to_dict() or {}
    group_ids = list(src_profile.get("groupIds", []))
    print(f"groups           {len(group_ids)}")
    for gid in group_ids:
        g_ref = db.collection("groups").document(gid)
        g = g_ref.get()
        if not g.exists:
            print(f"  - {gid}: group no longer exists, skipped")
            continue
        g_data = g.to_dict()
        member = g_ref.collection("members").document(src_uid).get()
        role = (member.to_dict() or {}).get("role", "member") if member.exists else "member"
        owner = g_data.get("ownerId") == src_uid
        print(f"  - {g_data.get('name')}: join as {role}" + ("  + transfer ownership" if owner else ""))
        m = member.to_dict() if member.exists else {"displayName": dst_email.split("@")[0], "role": role}
        m.pop("code", None)
        m["joinedAt"] = firestore.SERVER_TIMESTAMP
        queue(g_ref.collection("members").document(dst_uid), m)
        if owner:
            queue(g_ref, {"ownerId": dst_uid}, merge=True)
            for jc in db.collection("joinCodes").where("groupId", "==", gid).stream():
                queue(jc.reference, {"ownerId": dst_uid}, merge=True)
    if group_ids:
        queue(dst_ref, {"groupIds": firestore.ArrayUnion(group_ids)}, merge=True)

    if args.apply and pending:
        batch.commit()
    print()
    print("Done - open the app signed in as the destination account; data syncs in within seconds."
          if args.apply else "Dry run finished. Re-run with --apply to copy.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
