# Play Console → App content (answers)

Prepared from the code (`docs/DESIGN.md`). Re-check before each release.

## Data safety
**Collects data:** Yes. **Shares data:** No (Firebase/Google is a service provider).
**Encrypted in transit:** Yes.
**Account creation:** username/email + password.
**Deletion:** in-app (More → Delete my account) and https://school-supplies.homilabs.org/delete-account.html

| Data type | Collected | Shared | Purpose | Required? |
|---|---|---|---|---|
| Personal info → Name | Yes | No | App functionality, Account management | Required |
| Personal info → Email address | Yes | No | App functionality, Account management | Required |
| Personal info → Phone number (optional field on staff records) | Yes | No | App functionality | Optional |
| Personal info → Other info (role, employee no., duty area) | Yes | No | App functionality | Required |
| Everything else | No | — | — | — |

No analytics or crash SDK is included.

## Other declarations
- **Privacy policy:** https://school-supplies.homilabs.org/privacy.html
- **Ads:** No.
- **App access:** All functionality needs an account, but sign-up is open. Reviewer instructions below.
- **Target audience:** 18+. Not designed for children.
- **Content rating:** Utility/productivity. Violence, sexuality, language, drugs, gambling: none. User interaction: members of one school see each other's stock records, no public sharing or chat. Location sharing: no. Digital purchases: no.
- **Government / Financial / Health / News / COVID-19 / Dating:** none.
- **Advertising ID:** not used.
- **Permissions:** INTERNET, ACCESS_NETWORK_STATE only.

## Reviewer instructions (App access)
> Sign-up is open and needs no invitation. Open the app, tap "New here? Create an account", use any email and a password of 6+ characters, then under "Or set up a new school" enter any name and tap "Create school". You are now Incharge and Admin, and the standard item list is loaded. To test demand entry and issuing, change your role to Janitorial Supervisor under More > Users & roles. Add a staff member under More > Janitorial staff, then use "Enter demand slip" on Home.
