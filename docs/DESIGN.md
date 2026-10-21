# School Inventory — design (v1.0, 22 Oct 2026)

Janitorial stock control for Fatima Fertilizer School, built so any school can use it.
Flutter (Android) + Firebase Auth (email/password) + Cloud Firestore. Spark (free) plan: no Cloud Functions;
all integrity rules live in `firestore/firestore.rules`.

## People and roles

| Who | Signs in? | Role in app | Can |
|---|---|---|---|
| Janitorial staff | **No** (no phones allowed) | `staff` record | Their paper slip is entered by the supervisor; everything issued is tracked against their name |
| Janitorial Supervisor | Yes | `supervisor` | Add/edit items and staff, enter demand slips, **issue** approved demands, record stock received |
| Janitorial Incharge (rotating teacher) | Yes | `incharge` | Enter slips, **approve/reject** demands (can reduce quantities), **approve/reject** receipts, correct stock after a physical count |
| Viewer (principal, auditor) | Yes | `viewer` | Read-only + reports |
| Admin | — | `isAdmin` flag on any member | Approve join requests, change roles, grant/revoke admin, turn access off |

Admin is a **flag, not a role**, so it stays with one person (the founding incharge) while the incharge role
rotates: the admin simply changes who is `incharge`. An admin cannot remove their own admin flag or turn off
their own access (no lock-out). Several admins are allowed.

## Flows

```
Demand:   staff paper slip ─► supervisor enters (pending) ─► incharge approves / rejects
                              ─► supervisor issues (stock − qty, ledger entry per item) ─► issued
Receipt:  stock arrives / opening stock ─► supervisor records (pending) ─► incharge approves (stock + qty) / rejects
Count:    incharge enters counted quantity + reason ─► adjustment (stock set, ledger entry)
Join:     new user signs up ─► types 6-letter school code ─► pending ─► admin approves with a role
New school: first user creates it ─► becomes incharge + admin; optional standard 15-item list
```

Partial issue is allowed (issue ≤ approved and ≤ stock). Stock never goes below zero.
At most 10 items per slip/receipt (keeps every write within Firestore's rules access limit).

## Firestore data model (`schemaVersion: 1`)

```
users/{uid}                    displayName, email, orgId                     (own profile; pointer to school)
joinCodes/{CODE}               orgId, orgName                                (get-only lookup)
orgs/{orgId}                   name, joinCode, createdBy, createdAt, modules:['janitorial'], schemaVersion
  members/{uid}                uid, displayName, email, role, isAdmin, status(pending|active|disabled),
                               requestedRole, locationIds[], createdAt, approvedBy, approvedAt
  staff/{id}                   name, employeeNo, phone, dutyArea, locationId?, active
  items/{id}                   name, unit, category, reorderLevel, currentStock, active, lastRef{type,id}
  demands/{id}                 slipNo, staffId, staffName, locationId?, note, status, createdBy(+Name/At),
                               lines{itemId:{itemName,unit,qtyRequested,qtyApproved,qtyIssued}},
                               decidedBy(+Name/At), decisionNote, issuedBy(+Name/At)
  receipts/{id}                source, reference, note, status, lines{itemId:{itemName,unit,qty}}, created…/decided…
  adjustments/{id}             reason, lines{itemId:{itemName,unit,delta}}, createdBy(+Name/At)
  ledger/{refId_itemId}        itemId, itemName, unit, delta, balanceAfter, type(issue|receipt|adjustment),
                               refType, refId, staffId?, staffName, reason, by, byName, at     (immutable)
  locations/{id}               V2 hook — name (admin-managed; not used by the v1 UI)
```

### How the rules protect stock
`items.currentStock` can only change in the same atomic write that also
- moves a demand `approved → issued` (supervisor) and the change equals that line's `qtyIssued` (≤ approved), or
- moves a receipt `pending → approved` (incharge) and the change equals that line's `qty`, or
- creates a new adjustment (incharge) and the change equals its `delta`;

and the write must create the matching ledger entry `ledger/{refId}_{itemId}`, which can never be edited or
deleted. Replaying an old document fails because its status has already moved on. Tested in `tests/rules/`.

Known limit (accepted for v1): rules cannot loop over lines, so a hand-crafted client could mark a line as
issued without lowering that item's stock (it would then also have no ledger entry). The app never does this.

## V2 hooks (full school inventory, staff by location)
- `orgs.modules` and `items.category` (`'janitorial'` now) → add `stationery`, `furniture`, `IT`, `lab`…;
  filter screens by module; per-module incharges via `members.locationIds` or a future `moduleIds`.
- `locations` collection (already protected: admin writes, members read) → blocks/floors/washrooms.
  `staff.locationId`, `demands.locationId` and `members.locationIds` already exist in the schema.
- `Role` enum + `validRoles()` in rules → add e.g. `storeKeeper`, `locationLead`.
- `schemaVersion` on the org → forward-only migrations.
- Multi-school: already multi-tenant (`orgs/{orgId}`), so publishing for other schools needs no data change.

## Parked for V2 (decided 22 Oct 2026 — revisit after the school's first real use)
- **Notifications.** Preferred: Cloud Functions + FCM push (needs Blaze plan; set a budget alert) —
  incharge: new demand/receipt to approve; supervisor: approved/rejected; both: low stock;
  optional morning summary. Fallback without Blaze: WorkManager ~15-min background check + local
  notification (delayed; ColorOS battery limits).
- **Reports.** Monthly stock statement per item (opening + received − issued ± adjustments =
  closing) as printable PDF + CSV; one-tap current-stock export.
