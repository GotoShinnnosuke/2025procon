import 'package:url_launcher/url_launcher.dart';

class XShareService {
  static Future<bool> share({
    required String text,
    String? url,
    List<String>? hashtags,
  }) async {
    final buffer = StringBuffer();

    buffer.write(text);

    if (hashtags != null && hashtags.isNotEmpty) {
      buffer.write(' ');
      buffer.write(
        hashtags.map((e) => '#$e').join(' '),
      );
    }

    if (url != null) {
      buffer.write('\n');
      buffer.write(url);
    }

    final encoded = Uri.encodeComponent(buffer.toString());
    final uris = [
      Uri.parse('https://x.com/intent/post?text=$encoded'),
      Uri.parse('https://twitter.com/intent/tweet?text=$encoded'),
    ];

    for (final uri in uris) {
      try {
        final launchedBlank = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
        if (launchedBlank) return true;
        final launchedSelf = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
        if (launchedSelf) return true;
      } catch (_) {
        // 次の候補URLを試す
      }
    }
    return false;
  }
}
