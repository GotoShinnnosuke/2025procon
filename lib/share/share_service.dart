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
    if (kIsWeb && await _openXIntent(message)) {
      return true;
    }

    try {
      await Share.share(message);
      return true;
    } catch (e) {
      debugPrint('ShareService.share share_plus failed: $e');
    }

    if (await _openXIntent(message)) {
      return true;
    }

    await Clipboard.setData(ClipboardData(text: message));
    return false;
  }

  static Future<bool> _openXIntent(String message) async {
    final encoded = Uri.encodeComponent(message);
    final uris = [
      Uri.parse('https://x.com/intent/post?text=$encoded'),
      Uri.parse('https://twitter.com/intent/tweet?text=$encoded'),
    ];
    for (final uri in uris) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
        if (launched) return true;
      } catch (e) {
        debugPrint('ShareService.share X intent failed ($uri): $e');
      }
    }
    return false;
  }
}
