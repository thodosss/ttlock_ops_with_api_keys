# TTLock Ops

Flutter (Android) app για καθημερινές λειτουργίες TTLock μέσω του cloud API.  
Χωριστό από το `ttlock_app` (batch / 48ωρα)· εδώ το focus είναι login → λίστα κλειδαριών → unlock / κωδικοί / records / access / gateways.

## Τι κάνει

1. **Σύνδεση** με TTLock OAuth2 (`clientId` + `clientSecret` + username/password) **ή** έτοιμο `access_token`.
2. **Λίστα κλειδαριών** με φίλτρο (alias / name / MAC) και βασικά στοιχεία (μπαταρία, gateway).
3. **Λεπτομέρειες κλειδαριάς** (tabs):
   - Ops: remote unlock/lock, open state, battery, rename alias, freeze/unfreeze, gateways + RSSI
   - Passcodes: create (πολλοί τύποι / custom), edit, delete via gateway
   - Records: ιστορικό ανοιγμάτων με date filter
   - Access: ekeys (list/send/delete), IC cards (list/delete), fingerprints (read-only)
4. **Λίστα gateways** λογαριασμού (online status, MAC, πλήθος locks, δίκτυο).

Τα credentials αποθηκεύονται **τοπικά** στο device (`SharedPreferences`, prefix `ops_`) — δεν υπάρχουν hardcoded keys στο repo.

## Οθόνες

| Οθόνη | Αρχείο | Ρόλος |
|-------|--------|--------|
| Home | `lib/screens/home_screen.dart` | Login, φόρτωση locks, φίλτρο, πλοήγηση |
| Lock detail | `lib/screens/lock_detail_screen.dart` | Tabs: λεπτομέρειες / κωδικοί / records / access |
| Gateways | `lib/screens/gateways_screen.dart` | Λίστα Wi‑Fi gateways |

API client: `lib/ttlock_api.dart` · storage: `lib/storage.dart`

## Auth

**Mode A — username/password**

- `POST /oauth2/token`
- password στέλνεται ως **MD5** (απαίτηση TTLock)
- μετά `GET /v3/lock/list`

**Mode B — access token**

- toggle «Χρησιμοποίησε access token»
- χρειάζεται μόνο `clientId` + `access_token`

### API base URLs

- `https://euapi.ttlock.com` (default)
- `https://api.ttlock.com`
- `https://api.sciener.com`

## Cloud API endpoints που χρησιμοποιούνται

| Λειτουργία | Endpoint |
|------------|----------|
| Unlock / Lock | `/v3/lock/unlock`, `/v3/lock/lock` |
| Open state / battery | `/v3/lock/queryOpenState`, `/v3/lock/queryElectricQuantity` |
| Rename | `/v3/lock/rename` |
| Freeze / Unfreeze | `/v3/lock/freeze`, `/v3/lock/unfreeze` |
| Passcodes | `/v3/keyboardPwd/get`, `/add`, `/change`, `/delete`, `/lock/listKeyboardPwd` |
| Records | `/v3/lockRecord/list` |
| Ekeys | `/v3/lock/listKey`, `/v3/key/send`, `/v3/key/delete` |
| IC cards | `/v3/identityCard/list`, `/v3/identityCard/delete` |
| Fingerprints | `/v3/fingerprint/list` |
| Gateways | `/v3/gateway/list`, `/v3/gateway/listByLock` |

Gateway-only ενέργειες (`deleteType=2`, `changeType=2`, remote lock/unlock, freeze) απενεργοποιούνται όταν η κλειδαριά δεν έχει gateway.

## Απαιτήσεις

- Flutter SDK (project: `sdk: ^3.11.4`)
- Android device/emulator

## Run / APK

```bash
cd ttlock_ops
flutter pub get
flutter run

# Release APK
flutter build apk --no-tree-shake-icons
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Σημειώσεις ασφαλείας

- Μην κάνεις commit `.env`, keystores, ή πραγματικά `clientSecret` / tokens.
- Το app κρατά password & token σε plaintext SharedPreferences — για προσωπική/ops χρήση.
- Διαγραφή admin ekey στον server σβήνει όλα τα ekeys/passcodes — υπάρχει confirm dialog.
- Fingerprint enrollment και Bluetooth ops δεν υποστηρίζονται (χρειάζονται native SDK).
