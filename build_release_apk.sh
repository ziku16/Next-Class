#!/usr/bin/env bash
set -euo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
version="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+).*$/\1/p' "$repo_root/pubspec.yaml")"
build_number="$(sed -nE 's/^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+).*$/\1/p' "$repo_root/pubspec.yaml")"
signing_dir="${NEXTCLASS_SIGNING_DIR:-$HOME/NextClassSigning}"
keystore="$signing_dir/nextclass-release.jks"
key_properties="$repo_root/android/key.properties"
artifact_dir="$repo_root/build/release"
symbols_dir="$signing_dir/symbols-v$version"
apk_name="NextClass-v$version.apk"

if [[ -z "$version" || -z "$build_number" ]]; then
  echo "Could not read the app version from pubspec.yaml." >&2
  exit 1
fi
if [[ ! -f "$key_properties" || ! -f "$keystore" ]]; then
  echo "The existing production signing configuration or keystore is missing." >&2
  exit 1
fi
if ! grep -q '^storeFile=/home/zaki/NextClassSigning/nextclass-release\.jks$' "$key_properties"; then
  echo "android/key.properties does not reference the preserved production keystore." >&2
  exit 1
fi
if [[ ! -s "$key_properties" ]]; then
  echo "android/key.properties is empty." >&2
  exit 1
fi
if [[ -z "${NEXTCLASS_WORKER_URL:-}" ]]; then
  echo "Set NEXTCLASS_WORKER_URL to the existing public NextClass Worker origin." >&2
  exit 1
fi

mkdir -p "$artifact_dir" "$symbols_dir"
chmod 700 "$symbols_dir"
flutter build apk \
  --release \
  --build-name="$version" \
  --build-number="$build_number" \
  --target-platform=android-arm,android-arm64,android-x64 \
  --obfuscate \
  --split-debug-info="$symbols_dir" \
  --dart-define="NEXTCLASS_WORKER_URL=$NEXTCLASS_WORKER_URL"

built_apk="$repo_root/build/app/outputs/flutter-apk/app-release.apk"
test -s "$built_apk"
cp "$built_apk" "$artifact_dir/$apk_name"
(cd "$artifact_dir" && sha256sum "$apk_name" > "$apk_name.sha256")

for abi in armeabi-v7a arm64-v8a x86_64; do
  if ! unzip -Z1 "$artifact_dir/$apk_name" | grep -F "lib/$abi/" > /dev/null; then
    echo "Release APK is missing the $abi native libraries." >&2
    exit 1
  fi
done

echo "Built $artifact_dir/$apk_name"
du -h "$artifact_dir/$apk_name"
cat "$artifact_dir/$apk_name.sha256"
