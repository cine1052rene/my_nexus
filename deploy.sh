#!/bin/bash
# MyNexus 배포 스크립트
# Blaze 업그레이드 완료 후 실행
# 사용법: bash deploy.sh YOUR_GEMINI_API_KEY

set -e

GEMINI_KEY="$1"
ADB="C:/Users/cine1/AppData/Local/Android/Sdk/platform-tools/adb.exe"

echo "======================================"
echo " MyNexus 배포 시작"
echo "======================================"

# 1. Gemini API 키 확인
if [ -z "$GEMINI_KEY" ]; then
  echo ""
  echo "❌ Gemini API 키를 인수로 전달해주세요:"
  echo "   bash deploy.sh AIza..."
  echo ""
  echo "🔗 키 발급: https://aistudio.google.com/apikey"
  exit 1
fi

echo ""
echo "① GEMINI_API_KEY Secret Manager 등록 중..."
echo "$GEMINI_KEY" | npx firebase-tools functions:secrets:set GEMINI_API_KEY --project my-nexus-hub
echo "✅ Secret 등록 완료"

echo ""
echo "② Firebase Functions 배포 중..."
npx firebase-tools deploy --only functions --project my-nexus-hub
echo "✅ Functions 배포 완료"

echo ""
echo "③ Flutter APK 빌드 중..."
flutter build apk --release
echo "✅ APK 빌드 완료"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

echo ""
echo "④ 기기에 설치 중..."
"$ADB" install -r "$APK_PATH"
echo "✅ 설치 완료"

echo ""
echo "⑤ 앱 실행 중..."
"$ADB" shell am start -n "com.personal.nexus.my_nexus/com.personal.nexus.my_nexus.MainActivity"

echo ""
echo "======================================"
echo " ✅ 전체 배포 완료!"
echo " APK: $APK_PATH"
echo "======================================"
