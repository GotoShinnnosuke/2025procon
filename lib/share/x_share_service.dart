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

    final intentUrl = 'https://twitter.com/intent/tweet?text=$encoded';

    final uri = Uri.parse(intentUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      return true;
    }
    return false;
  }
}
