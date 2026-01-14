import 'package:flutter/material.dart';

import 'share_service.dart';
import 'x_share_service.dart';
import 'share_templates.dart';

class ShareButton extends StatelessWidget {
  final ShareData data;
  final bool xDirect; // trueならX直行

  const ShareButton({
    super.key,
    required this.data,
    this.xDirect = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () {
        if (xDirect) {
          XShareService.share(
            text: data.text,
            url: data.url,
            hashtags: data.hashtags,
          );
        } else {
          ShareService.share(
            text: data.text,
            url: data.url,
            hashtags: data.hashtags,
          );
        }
      },
    );
  }
}
