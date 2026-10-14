# Releasing LockIME Voice

Releases are **automated**: tag a commit and `.github/workflows/release.yml`
builds both architectures, verifies them, and publishes a GitHub Release with the
installers and a `SHA256SUMS.txt`. This fork still has no Apple Developer
membership, Developer ID certificate, notarization credentials, Sparkle signing
key, public update feed, or Homebrew cask.

## Release in one step

```sh
# 1. Bump the version in project.yml (MARKETING_VERSION, CURRENT_PROJECT_VERSION)
#    and update the download links in the READMEs to match.
# 2. Write the release notes at docs/release-notes/<version>.md — the workflow
#    refuses to publish without them (see below).
# 3. Commit, then tag and push:
git tag v0.1.3
git push origin v0.1.3
```

That triggers the `Release` workflow:

1. **test** — runs the full suite on the tagged commit. Installers are ad-hoc
   signed, so a Release is only trustworthy if the tests behind it passed.
2. **build** — builds `arm64` and `x86_64` in parallel (`fail-fast`, so a failure
   in one architecture never produces a partial Release) and, per architecture,
   verifies:
   - bundle identifier is `com.zhangsiqiang519.LockIMEVoice`;
   - `lipo -archs` matches the matrix architecture (a fat binary means the arch
     override was lost);
   - `codesign --verify --deep --strict` passes and the signature is `adhoc`;
   - the app does **not** carry `com.apple.security.get-task-allow` (that key
     marks a build as debuggable and must not ship — see `project.yml`);
   - for tags, `MARKETING_VERSION` equals the tag, so the built app can never
     disagree with the release name;
   - the DMG mounts and the app *inside* it is re-verified.
3. **publish** — runs only for tags (a manual `workflow_dispatch` run stops after
   building and leaves the DMGs as workflow artifacts, never a public Release).
   It combines the per-arch checksums into `SHA256SUMS.txt` and creates the
   Release, re-uploading with `--clobber` so re-running the same tag is
   idempotent.

## Release notes are part of the release

The GitHub Release body comes from `docs/release-notes/<version>.md`, plus an
installer table and the checksum instructions the workflow appends. A missing
file fails the run rather than publishing a body that only says "ad-hoc signed,
not notarized" — a Release that does not tell users what changed is worse than a
failed pipeline.

Because the notes live in the tagged commit, they are reviewed in the same diff
as the code they describe. See `docs/release-notes/README.md` for what to include
(lead with user-visible changes, flag anything the user must reconfigure, leave
out the install boilerplate).

User-facing highlights should also be reflected in the READMEs' feature lists —
the Release notes explain *this* version, the README describes the product.

## Version numbers

`MARKETING_VERSION` in `project.yml` is the single source of truth;
`CURRENT_PROJECT_VERSION` must increase monotonically (Sparkle compares it
numerically, so a later build must never carry a smaller number). The DMG is
named `LockIME-Voice-<MARKETING_VERSION>-<arch>.dmg`.

**Checksums are never committed.** The DMG is not byte-reproducible — two local
builds of the same architecture produce different bytes — so a hash written into
the README would be wrong the moment CI rebuilds. The READMEs therefore point at
the release's own `SHA256SUMS.txt`, which the workflow generates from the exact
artifacts it uploads.

## Current distribution boundary

- `.github/workflows/ci.yml` builds and tests pull requests and `main`.
- `.github/workflows/release.yml` publishes tagged releases (above).
- `make build` creates `LockIME Voice Dev.app`, ad-hoc signed for local use.
- `make build CONFIG=Release` creates `LockIME Voice.app`, also ad-hoc signed.
- `make dmg CONFIG=Release` packages that app without notarizing the image.
- Normal Debug and Release builds do not start Sparkle or contain a production
  `SUFeedURL` / `SUPublicEDKey`, so **there is no in-app automatic update yet**.
- `make update-test-*` remains a local-only loopback laboratory. It uses a
  throwaway update key and never contacts a production feed.

Ad-hoc artifacts are preview outputs, not trusted Developer ID releases.
Gatekeeper blocks the first launch: the user must click **Open Anyway** in
**System Settings ▸ Privacy & Security**. macOS can also require Accessibility
permission again after each reinstall or rebuild.

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

Package each architecture immediately after its build, before the next build
overwrites the shared Release product path:

```sh
scripts/make-dmg.sh \
  'build/DerivedData/Build/Products/Release/LockIME Voice.app' \
  'build/dmg/LockIME-Voice-<version>-<arch>.dmg'
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

## Adding in-app automatic updates

Automatic updates need a Sparkle feed this fork owns. Upstream's `gh-pages`
appcast belongs to `oomol-lab/LockIME` and is signed with *their* key — never
reuse it, never reuse their feed URL, and never point `SUFeedURL` at it. Doing
so would let a third party's release install over this fork's build.

To enable updates, in this order:

1. Generate a fork-owned EdDSA key pair (`generate_keys`, shipped in
   `Sparkle/bin`); store the private key as a GitHub Actions secret and add the
   public key to `Info.plist` as `SUPublicEDKey`.
2. Add `SUFeedURL` pointing at this fork's own HTTPS appcast.
3. Extend the release workflow to run `generate_appcast` (or hand-maintain
   `appcast.xml`) and sign each DMG with `sign_update`, then deploy the appcast
   to this fork's `gh-pages`.
4. Stop gating `UpdateController.start()` on `#if DEBUG` and remove the
   "Release builds never construct Sparkle" branch.

Because the installers are unnotarized, an update installs an unnotarized build
too, so users may be asked to re-approve Accessibility afterwards.

## Enabling notarized releases later

Do not restore the upstream workflows or credentials. Build a notarized pipeline
owned by this fork only after all of these are available:

1. Apple Developer Program membership.
2. A Developer ID Application certificate owned by the maintainer.
3. App Store Connect notarization credentials.

The required signing order is `codesign -> notarize -> staple -> package`. Never
reuse upstream certificates, Team IDs, Sparkle keys, feeds, or Homebrew
automation.
