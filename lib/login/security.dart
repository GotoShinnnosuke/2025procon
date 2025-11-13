import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mypage.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _newEmailController = TextEditingController();

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  /// 🔑 パスワード再設定メールを送信
  Future<void> _sendPasswordResetEmail() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現在ログインしているユーザーのメールが確認できません。')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('パスワード再設定メールを送信しました'),
            content: Text(
              '登録メールアドレス「${user.email}」宛に再設定メールを送信しました。\n'
              'メール内のリンクからパスワードをリセットしてください。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'エラーが発生しました: ${e.message}';
      if (e.code == 'invalid-email') {
        message = 'メールアドレスの形式が正しくありません。';
      } else if (e.code == 'user-not-found') {
        message = 'ユーザーが見つかりませんでした。';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パスワード設定')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // メールアドレス変更

            const Divider(height: 40, thickness: 1),
            // パスワード再設定
            ElevatedButton.icon(
              onPressed: _sendPasswordResetEmail,
              icon: const Icon(Icons.lock_reset),
              label: const Text('パスワードをリセット'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
