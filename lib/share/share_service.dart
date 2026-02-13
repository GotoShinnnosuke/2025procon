import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareService {
  static String compose({
    required String text,
    String? url,
    List<String>? hashtags,
  }) {
    final buffer = StringBuffer()..writeln(text);

    if (hashtags != null && hashtags.isNotEmpty) {
      buffer.writeln(hashtags.map((e) => '#$e').join(' '));
    }

    if (url != null && url.isNotEmpty) {
      buffer.writeln(url);
    }

    return buffer.toString().trim();
  }

  /// `true`: 共有UI/外部共有まで完了
  /// `false`: 共有UIが使えず、テキストコピーでフォールバック
  static Future<bool> share({
    required String text,
    String? url,
    List<String>? hashtags,
  }) async {
    final message = compose(text: text, url: url, hashtags: hashtags);

    try {
      await Share.share(message);
      return true;
    } catch (e) {
      debugPrint('ShareService.share share_plus failed: $e');
    }

    final intent = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(intent)) {
        await launchUrl(
          intent,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
        return true;
      }
    } catch (e) {
      debugPrint('ShareService.share URL fallback failed: $e');
    }

    await Clipboard.setData(ClipboardData(text: message));
    return false;
  }
}
