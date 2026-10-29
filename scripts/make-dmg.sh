#!/usr/bin/env bash
# Package a macOS .app into a distributable, drag-to-install .dmg.
#
# The image holds the app beside an /Applications symlink so it opens to the
# familiar "drag the app onto Applications" layout. Intentionally dependency-free
# (hdiutil only) so it behaves identically on a developer's machine and on the CI
# runners, which install nothing beyond xcodegen.
#
# Signing and notarization are deliberately NOT done here. This source fork has
# no public signing workflow, so `make dmg` produces an ad-hoc, unnotarized image.
#
#   make-dmg.sh <app-path> <output-dmg> [volume-name]
set -euo pipefail

APP="${1:?usage: make-dmg.sh <app-path> <output-dmg> [volume-name]}"
OUT="${2:?usage: make-dmg.sh <app-path> <output-dmg> [volume-name]}"
VOL="${3:-$(basename "${APP%.app}")}"

[ -d "$APP" ] || { echo "make-dmg: app not found: $APP" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Copy the bundle (ditto preserves symlinks, xattrs and the code signature) and
# drop an /Applications alias next to it for drag-to-install.
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"

# The image is also the first-run tutorial. These installers are ad-hoc signed and
# unnotarized, so the first launch is refused with "Apple could not verify ..." —
# which reads like a broken download and stops most people right there. Write the
# way out next to the drag target, in the window the user is already looking at.
# A plain text file on purpose: no Finder/AppleScript layout pass, so the image is
# built the same way on a developer's machine and on CI (see docs/RELEASING.md).
cat > "$STAGE/Install notes — 安装说明.txt" <<'NOTE'
LockIME Voice — 安装说明 / Install notes
=======================================

1. 把左边的 "LockIME Voice" 拖到右边的 Applications（应用程序）文件夹。
   Drag "LockIME Voice" onto the Applications folder on the right.

2. 第一次打开时，若提示「无法验证」或
   “Apple could not verify “LockIME Voice” is free of malware”
   —— 这是未公证（ad-hoc 签名）的正常提示，不是下载损坏。
      If macOS cannot verify the app, that is expected: these preview builds are
      ad-hoc signed and not notarized. The download is not corrupt.

   解决方法 / To open it anyway:
     系统设置 ▸ 隐私与安全性 ▸ 安全性（页面底部）
     System Settings ▸ Privacy & Security ▸ Security (bottom of the page)
     点 “仍要打开” 并输入密码，再确认一次。
     Click “Open Anyway”, authenticate, then confirm “Open Anyway”.

3. 语音快捷键需要授权：
   The voice shortcut needs one permission:
     系统设置 ▸ 隐私与安全性 ▸ 辅助功能 ▸ 打开 “LockIME Voice”
     System Settings ▸ Privacy & Security ▸ Accessibility ▸ enable “LockIME Voice”
   不需要「输入监控」，这个 App 不监听你的键盘。
   Input Monitoring is NOT needed — LockIME never listens to your typing.

安装包校验 / Verify the download:
   shasum -a 256 -c SHA256SUMS.txt
   (SHA256SUMS.txt is attached to the same GitHub Release.)
NOTE

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

# ULFO (LZFSE) over the historical UDZO (zlib): squeezes the Mach-O binary and
# the embedded Sparkle framework harder (the .car app-icon bitmaps are already
# lzfse and barely move). LZFSE is Apple's own codec, decoded in userspace by
# the host OS's DiskImages helper (a universal binary) — so mountability tracks
# the host macOS version, never the contained app's CPU arch: the x86_64 image
# mounts exactly the same. ULFO mounts on every macOS ≥ 10.11 (our floor is
# 14.0). The .dmg is a manually uploaded preview artifact; this fork has no
# Sparkle feed or signing pipeline, so it remains ad-hoc signed and unnotarized
# (see docs/RELEASING.md).
hdiutil create \
	-volname "$VOL" \
	-srcfolder "$STAGE" \
	-fs HFS+ \
	-format ULFO \
	-ov -quiet \
	"$OUT"

echo "make-dmg: wrote $OUT"
