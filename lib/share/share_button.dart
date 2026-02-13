import 'package:flutter/material.dart';

import 'share_service.dart';
import 'x_share_service.dart';
import 'share_templates.dart';

class ShareButton extends StatelessWidget {
  final ShareData data;
  final bool xDirect;

  const ShareButton({
    super.key,
    required this.data,
    this.xDirect = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () async {
        try {
          if (xDirect) {
            final shared = await XShareService.share(
              text: data.text,
              url: data.url,
              hashtags: data.hashtags,
            );
            if (!context.mounted) return;
            if (!shared) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Xへの共有を開けなかったため、通常共有をお試しください'),
                ),
              );
            }
            return;
          }
          final shared = await ShareService.share(
            text: data.text,
            url: data.url,
            hashtags: data.hashtags,
          );
          if (!context.mounted) return;
          if (!shared) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('共有機能が利用できないため、投稿文をコピーしました'),
              ),
            );
          }
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('共有に失敗しました: $e')),
          );
        }
      },
    );
  }
}
