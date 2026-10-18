# google_mlkit_text_recognition 플러그인은 모든 문자 체계(중국어·일본어·데바나가리)
# 옵션 클래스를 참조하지만, 우리는 한국어 모델만 넣는다(build.gradle.kts).
# 쓰지 않는 모델 클래스가 없다고 R8이 빌드를 막으므로 경고를 끈다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
