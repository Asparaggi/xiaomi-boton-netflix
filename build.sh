#!/usr/bin/env bash
set -euo pipefail

BT=$ANDROID_SDK_ROOT/build-tools/34.0.0
PLATFORM=$ANDROID_SDK_ROOT/platforms/android-34/android.jar
OUT=/work/build
KEYSTORE=/work/keystore/debug.keystore

rm -rf "$OUT"
mkdir -p "$OUT/classes" "$OUT/dex" /work/keystore

"$BT/aapt2" link -o "$OUT/unsigned.apk" \
    --manifest /work/AndroidManifest.xml \
    -I "$PLATFORM" \
    --min-sdk-version 21 --target-sdk-version 34 \
    --version-code 1 --version-name 1.0

javac -source 8 -target 8 -bootclasspath "$PLATFORM" -nowarn -Xlint:-options \
    -d "$OUT/classes" $(find /work/src -name '*.java')

"$BT/d8" --release --min-api 21 --lib "$PLATFORM" \
    --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')

(cd "$OUT/dex" && zip -q -j "$OUT/unsigned.apk" classes.dex)

"$BT/zipalign" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

if [ ! -f "$KEYSTORE" ]; then
    keytool -genkeypair -keystore "$KEYSTORE" -storepass android -keypass android \
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US"
fi

"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
    --out /work/boton-netflix.apk "$OUT/aligned.apk"
"$BT/apksigner" verify /work/boton-netflix.apk

echo "APK listo: boton-netflix.apk"
