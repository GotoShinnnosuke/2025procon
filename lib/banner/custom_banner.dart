import 'package:flutter/material.dart';

class CustomBanner extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const CustomBanner({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        height: 80, // 高さを固定
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // 画像が切れても違和感がないよう、背景を黒（または画像に近い色）に
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.0),
          child: Row(
            children: [
              // --- 左側：キャラクター画像エリア ---
              // 背景をオレンジにし、キャラクターの全身が収まるように設定
              Container(
                width: 100, // キャラクター用に少し幅を広げる
                height: double.infinity,
                color: const Color(0xFFFFAB4C), // 最初のデザインのオレンジ色
                child: Image.asset(
                  'assets/images/character_noukin.png',
                  fit: BoxFit.contain, // 画像を「枠内に収める」設定（はみ出さない）
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.image,
                    color: Colors.white,
                  ),
                ),
              ),

              // --- 右側：テキストエリア ---
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft, // 文字を左寄せ（画像の横）
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white, // 黒背景に映える白文字
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
