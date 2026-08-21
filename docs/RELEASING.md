# Releasing LockIME Voice

LockIME Voice currently ships as source code only. The repository has no Apple
Developer membership, Developer ID certificate, notarization credentials,
Sparkle signing key, public update feed, Homebrew cask, or binary publishing
workflow.

## Current distribution boundary

- `.github/workflows/ci.yml` builds and tests pull requests and `main`.
- `make build` creates `LockIME Voice Dev.app`, ad-hoc signed for local use.
- `make build CONFIG=Release` creates `LockIME Voice.app`, also ad-hoc signed.
- `make dmg CONFIG=Release` packages that app without notarizing the image.
- Release and nightly publishing workflows are intentionally absent.
- Normal Debug and Release builds do not start Sparkle or contain a production
  `SUFeedURL` / `SUPublicEDKey`.
- `make update-test-*` remains a local-only loopback laboratory. It uses a
  throwaway update key and never contacts a production feed.

Ad-hoc artifacts are development outputs, not public releases. Gatekeeper may
block downloaded copies, and macOS can require Accessibility and Input
Monitoring permissions again after each rebuild.

## Local artifacts

Build the current architecture:

```sh
make build
make build CONFIG=Release
make dmg CONFIG=Release
```

Cross-build Intel on Apple silicon:

```sh
make build CONFIG=Release ARCH=x86_64
```

Before sharing any artifact, verify its identity and ad-hoc signature:

```sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
  'build/DerivedData/Build/Products/Release/LockIME Voice.app/Contents/Info.plist'
codesign --verify --deep --strict --verbose=2 \
  'build/DerivedData/Build/Products/Release/LockIME Voice.app'
```

The expected bundle identifier is `com.zhangsiqiang519.LockIMEVoice`, and
`codesign -dv --verbose=4` should report `Signature=adhoc` with no Team ID.

## Enabling public binary releases later

Do not restore the upstream workflows or credentials. Build a new distribution
pipeline owned by this fork only after all of these are available:

1. Apple Developer Program membership.
2. A Developer ID Application certificate owned by the maintainer.
3. App Store Connect notarization credentials.
4. A new Sparkle EdDSA key pair and fork-owned HTTPS appcast.
5. Fork-owned GitHub Actions secrets and release URLs.
6. Signed and notarized arm64/x86_64 artifacts validated with `codesign`,
   `spctl`, `notarytool`, and `stapler`.

The required signing order is `codesign -> notarize -> staple -> package`. Never
reuse upstream certificates, Team IDs, Sparkle keys, feeds, or Homebrew
automation.
