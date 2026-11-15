# Releasing The Last Light to TestFlight

Same setup as ScanIt and Aaru: fastlane, signing through the shared match repo
(`NorthAIProject/north-ios-certificates`), team `84X9WYBF36`, bundle id
`com.fernandocorreia.lastlight`.

## One-time setup

1. **Repo secrets** on `FACorreiaa/game-proto` — the same five values the other apps use:
   `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `MATCH_PASSWORD`,
   `MATCH_GIT_BASIC_AUTHORIZATION`. For example: `gh secret set ASC_KEY_ID --repo FACorreiaa/game-proto`.
   The match token needs write access for step 2.
2. **Seed signing:** Actions → *iOS beta* → Run workflow → lane `seed_signing`. It registers the
   App ID if it does not exist and adds the app's App Store profile to the match repo.
3. **App record:** in App Store Connect, My Apps → + → New App: platform iOS, name
   "The Last Light" (or any free name), bundle id `com.fernandocorreia.lastlight`, any SKU.
   Apple's API key cannot create app records, so this step is manual. Add yourself to the app's
   internal testers.

## Each beta

Merging to `main` runs the unit tests and then `fastlane beta`: Release build → TestFlight,
internal testers only. Or run it on demand: Actions → *iOS beta* → lane `beta`.

Locally, with the five variables exported:

```bash
cd LastLight && bundle install
bundle exec fastlane beta
```

The build number is read from App Store Connect and incremented; the marketing version is
`MARKETING_VERSION` in the Xcode project.

## Notes

- The app icon in `LastLight/LastLight/Assets.xcassets` is a placeholder made by script.
- Without the secrets, the workflow skips the upload with a warning rather than failing.
