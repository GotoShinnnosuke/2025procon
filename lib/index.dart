import 'package:fitness/profire_view_page.dart';
import 'package:flutter/material.dart';
class IndexPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('メニュー'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.person),
              label: Text('プロフィール'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileView()),
                );
              },
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.logout),
              label: Text('ログアウト'),
              onPressed: () {
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('ログアウト確認'),
          content: Text('本当にログアウトしますか？'),
          actions: [
            TextButton(
              child: Text('キャンセル'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // ダイアログを閉じる
              },
            ),
            TextButton(
              child: Text('ログアウト'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // ダイアログを閉じる
                Navigator.popUntil(context, ModalRoute.withName('/')); // ログイン画面へ戻る
              }
            ),
          ],
        );
      }
    );
  }
}
