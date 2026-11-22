#!/bin/bash
# 打包 Cloudflare 账号管理 APK（不走 Gradle：本机 JVM 联网被沙箱拦截；
# 步骤与 speed-test 相同：aapt2 编译资源 + javac + d8 dex + zipalign + apksigner）。
set -e
set -o pipefail
export JAVA_HOME=~/workspace/tools/jdk17
export PATH=$JAVA_HOME/bin:$PATH
BT=~/workspace/android-sdk/build-tools/34.0.0
AJAR=~/workspace/android-sdk/platforms/android-34/android.jar
PROJ=~/workspace/cloudflare-app/android
OUT=/tmp/cfapp-apk
rm -rf "$OUT"; mkdir -p "$OUT/classes" "$OUT/dex"

# 网页版是唯一源码：每次打包都把根目录的 index.html 拷进壳的 assets，
# 这样仓库里只留一份 index.html，别人 clone 下来直接跑这个脚本就能打包。
cp "$PROJ/../index.html" "$PROJ/app/src/main/assets/index.html"

echo "== aapt2 compile =="
"$BT/aapt2" compile --dir "$PROJ/app/src/main/res" -o "$OUT/compiled.zip"

echo "== aapt2 link =="
"$BT/aapt2" link -I "$AJAR" \
  --manifest "$PROJ/app/src/main/AndroidManifest.xml" \
  -R "$OUT/compiled.zip" --auto-add-overlay \
  -A "$PROJ/app/src/main/assets" \
  --min-sdk-version 24 --target-sdk-version 34 \
  -o "$OUT/app-unaligned.apk"

echo "== javac =="
javac -encoding UTF-8 -source 8 -target 8 -cp "$AJAR" -d "$OUT/classes" \
  "$PROJ/app/src/main/java/com/sunyazhong/cloudflare/MainActivity.java" 2>&1 | grep -v "obsolete" || true

echo "== d8 =="
# 注意：必须把全部 .class 文件都传给 d8，不能只传 MainActivity.class。
# 只传单个文件会丢掉匿名内部类（如 WebChromeClient 的 MainActivity$1），
# 运行时 new WebChromeClient(){...} 报 NoClassDefFoundError，启动即闪退。
# 2026-11-22 v1.1.0 就是这么坏的，教训。
# （d8 不接受目录作输入，用 glob 把目录下所有 .class 都传进去。）
"$BT/d8" --release --lib "$AJAR" --output "$OUT/dex" "$OUT/classes/com/sunyazhong/cloudflare/"*.class

echo "== add classes.dex =="
cd "$OUT/dex" && zip -q "$OUT/app-unaligned.apk" classes.dex && cd -

echo "== zipalign =="
"$BT/zipalign" -f -p 4 "$OUT/app-unaligned.apk" "$OUT/app-aligned.apk"

echo "== keystore (debug, kept in project so later versions keep the same signature) =="
KEYSTORE="$PROJ/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US" 2>&1 | tail -1
fi

echo "== apksigner =="
mkdir -p ~/workspace/your_files/cloudflare
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
  --out ~/workspace/your_files/cloudflare/cloudflare-v1.3.0.apk "$OUT/app-aligned.apk"

echo "== verify =="
"$BT/apksigner" verify --print-certs ~/workspace/your_files/cloudflare/cloudflare-v1.3.0.apk
"$BT/aapt2" dump badging ~/workspace/your_files/cloudflare/cloudflare-v1.3.0.apk | head -8
ls -la ~/workspace/your_files/cloudflare/cloudflare-v1.3.0.apk
