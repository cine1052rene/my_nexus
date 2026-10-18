import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'thumbnail_store.dart';

/// 캡처 한 장을 처리한 결과.
class CaptureResult {
  final String imageUrl; // Storage 다운로드 주소
  final String ocrText; // 기기에서 읽은 글자 (없으면 '')
  const CaptureResult(this.imageUrl, this.ocrText);
}

/// 공유받은 캡처 이미지 → 글자 인식 → 압축 → Storage 업로드.
///
/// - 글자 인식은 ML Kit 한국어 모델로 **기기 안에서** 처리한다 (서버·AI 비용 0).
///   그래서 "모공 기초제품"처럼 캡처 속 글자로 검색할 수 있게 된다.
/// - 원본 캡처(1440x3088 PNG면 2~4MB)를 그대로 올리지 않고 긴 변 1600px
///   JPEG 80으로 줄인다. 글자가 읽힐 정도는 유지하면서 보관비를 줄이기 위함.
/// - 경로 `users/{uid}/captures/{itemId}` — 계정 삭제 시 서버가 users/{uid}/
///   전체를 지우고, 항목 삭제 시 [delete]로 지운다.
class CaptureService {
  CaptureService._();

  static FirebaseStorage get _storage =>
      FirebaseStorage.instanceFor(bucket: ThumbnailStore.bucket);

  static Reference? _ref(String itemId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _storage.ref('users/$uid/captures/$itemId');
  }

  /// 처리 실패 시 예외를 던진다 (호출자가 사용자에게 알린다).
  static Future<CaptureResult> process(String itemId, String imagePath) async {
    final ref = _ref(itemId);
    if (ref == null) throw StateError('로그인이 필요합니다.');

    final ocr = await _recognize(imagePath);

    final bytes = await FlutterImageCompress.compressWithFile(
      imagePath,
      minWidth: 1600,
      minHeight: 1600,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    if (bytes == null || bytes.isEmpty) throw StateError('이미지를 읽지 못했어요.');

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    // 네이티브가 캐시에 복사해 둔 원본은 더 쓸 일이 없다.
    try {
      await File(imagePath).delete();
    } catch (_) {}

    return CaptureResult(url, ocr);
  }

  static Future<String> _recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text.trim();
    } catch (_) {
      return ''; // 글자 인식 실패해도 이미지는 저장한다
    } finally {
      await recognizer.close();
    }
  }

  /// 항목 삭제 시 이미지도 지운다 (없으면 조용히 넘어감).
  static Future<void> delete(String itemId) async {
    try {
      await _ref(itemId)?.delete();
    } catch (_) {}
  }
}
