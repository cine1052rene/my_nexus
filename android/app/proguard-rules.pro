# google_mlkit_text_recognition 플러그인은 모든 문자 체계(중국어·일본어·데바나가리)
# 옵션 클래스를 참조하지만, 우리는 한국어 모델만 넣는다(build.gradle.kts).
# 쓰지 않는 모델 클래스가 없다고 R8이 빌드를 막으므로 경고를 끈다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**

# ML Kit은 내부 부품을 리플렉션으로 등록한다. R8이 이를 지우거나 이름을 바꾸면
# 실기기에서 TextRecognizer가 NullPointerException
# (mlkit_vision_common ... getClass() on a null object)으로 실패한다.
# 2026-10-20 S23 Ultra에서 실제로 발생 — 글자 인식 0자. ML Kit 전체를 보존한다.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-keep class com.google.android.gms.vision.** { *; }
