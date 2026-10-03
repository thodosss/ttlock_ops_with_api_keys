# TTLock Ops

Νέο Android app για βασικές λειτουργίες TTLock (χωριστό από το `ttlock_app` / batch 48ωρα).

## Λειτουργίες

- Login: `clientId` + `clientSecret` + username/password **ή** `clientId` + access token
- Λίστα κλειδαριών + φίλτρο
- Λίστα gateways
- Remote unlock (αν υπάρχει gateway)
- Passcodes με datepicker (cloud period ή custom 5ψήφιο via gateway)

## Run / APK

```bash
cd ttlock_ops
flutter pub get
flutter run
flutter build apk --no-tree-shake-icons
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
