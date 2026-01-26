import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 追加
import 'package:cached_network_image/cached_network_image.dart'; // 追加

class CustomBanner extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final String storagePath; // Storage内のパス（例: 'banners/character.png'）

  const CustomBanner({
    super.key,
    required this.title,
    required this.onTap,
    this.storagePath = 'assets/images/character_noukin.png', // デフォルト値
  });

  // StorageからURLを取得する関数
  Future<String> _getImageUrl(String path) async {
    return await FirebaseStorage.instance.ref().child(path).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
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
              Container(
                width: 100,
                height: double.infinity,
                color: const Color(0xFFFFAB4C),
                // --- 修正ポイント：FutureBuilderでURLを取得して表示 ---
                child: FutureBuilder<String>(
                  future: _getImageUrl(storagePath),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return const Icon(Icons.error, color: Colors.white);
                    }

                    return CachedNetworkImage(
                      imageUrl: snapshot.data!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    );
                  },
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
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