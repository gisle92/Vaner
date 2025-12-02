# Vaner

Vaner is a minimal habit-tracking app powered by Firebase Auth, Firestore and
Firebase Cloud Messaging. Users can log daily progress, review streak stats and
now share their progress directly to any installed social app.

## Features
- Email / OAuth sign-in through Firebase Auth
- Daily log of each active habit with done / skipped actions
- Detailed streak + goal stats per habit
- Push notification scheduling (mobile)
- One-tap sharing of today's progress to the native share sheet

## Sharing your vaner
1. Open the home screen once the habits list has loaded.
2. Tap the new share icon in the top app bar.
3. Pick Instagram, Facebook or any other installed target from the OS share
   sheet to publish your progress summary (e.g. “3 / 4 vaner gjort i dag”).

The shared message includes:
- Total count of active habits
- How many were completed, skipped or still undecided today
- A friendly nudge that the progress comes from Vaner

## Local development
```
flutter pub get
flutter run
```

> Note: `share_plus` is now required for the sharing UX. Run `flutter pub get`
after pulling to make sure the plugin is downloaded before building.
