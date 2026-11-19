import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/brand_background.dart';

const _kPrivacyUrl = 'https://my-nexus-hub.web.app/privacy';

/// 첫 화면(로그인). 2026-11-19 리디자인 — 예전엔 🤖 이모지 로고에
/// "폰 캘린더 연동·Gemini 챗봇" 같은 옛 기능 소개가 남아 있었다.
/// 지금은 실제 앱 아이콘 + 브랜드 보라 배경 + 스토어 등록정보와 같은 기능 소개.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: LayoutBuilder(
            // 작은 화면에서도 넘치지 않게: 화면보다 길면 스크롤, 아니면 Spacer로 배치
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        const BrandLogo(size: 112),
                        const SizedBox(height: 28),
                        const Text(
                          'MyNexus',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '저장만 하고 못 찾던 것들,\n이제 한 곳에서 바로 찾으세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const Spacer(flex: 2),
                        const _FeatureCard(),
                        const Spacer(flex: 3),
                        _GoogleButton(
                          loading: isLoading,
                          onPressed: () => _signIn(context, ref),
                        ),
                        const SizedBox(height: 18),
                        const _PrivacyNotice(),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final error =
        await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red[400]),
      );
    }
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _GoogleButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.85),
            foregroundColor: const Color(0xFF1F1F1F),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: BrandColors.purple,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 구글 공식 G 로고 (브랜딩 가이드 색상 그대로, assets/images)
                    Image.asset('assets/images/google_g.png',
                        width: 20, height: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Google로 계속하기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      );
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 11.5,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          children: [
            const TextSpan(text: '로그인하면 '),
            TextSpan(
              text: '개인정보 처리방침',
              style: TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(
                      Uri.parse(_kPrivacyUrl),
                      mode: LaunchMode.externalApplication,
                    ),
            ),
            const TextSpan(text: '에 동의하게 돼요.'),
          ],
        ),
        textAlign: TextAlign.center,
      );
}

/// 기능 소개 카드 — 반투명 판 위에 세 줄.
/// 스토어 등록정보(2026-11-19)와 같은 기능·표현을 쓴다.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Column(
          children: [
            _FeatureRow(
              icon: Icons.link_rounded,
              title: '링크·영상 자동 정리',
              sub: '공유만 하면 제목과 썸네일까지',
            ),
            SizedBox(height: 16),
            _FeatureRow(
              icon: Icons.document_scanner_outlined,
              title: '캡처 속 글자까지 검색',
              sub: '이미지 안의 단어로도 찾아요',
            ),
            SizedBox(height: 16),
            _FeatureRow(
              icon: Icons.auto_awesome_rounded,
              title: '물어보면 AI가 찾아줘요',
              sub: '"요리 링크 보여줘"처럼 말로',
            ),
          ],
        ),
      );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _FeatureRow(
      {required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: BrandColors.mint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: BrandColors.mint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
