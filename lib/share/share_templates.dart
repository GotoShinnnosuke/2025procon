class ShareData {
  final String text;
  final String? url;
  final List<String>? hashtags;

  ShareData({
    required this.text,
    this.url,
    this.hashtags,
  });
}

class ShareTemplates {
  static ShareData result({
    required int score,
    required String url,
  }) {
    return ShareData(
      text: '今回の結果は $score 点でした！',
      url: url,
      hashtags: ['アプリ名', '結果共有'],
    );
  }

  static ShareData plain({
    required String message,
    String? url,
  }) {
    return ShareData(
      text: message,
      url: url,
      hashtags: ['ダイエット支援アプリ'],
    );
  }
}
