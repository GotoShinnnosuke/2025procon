import 'package:share_plus/share_plus.dart';
//変更
class ShareService {
  static Future<void> share({
    required String text,
    String? url,
    List<String>? hashtags,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln(text);

    if (hashtags != null && hashtags.isNotEmpty) {
      buffer.writeln(
        hashtags.map((e) => '#$e').join(' '),
      );
    }

    if (url != null) {
      buffer.writeln(url);
    }

    await Share.share(buffer.toString().trim());
  }
}
