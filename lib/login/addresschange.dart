import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Addresschange extends StatefulWidget {
  const Addresschange({super.key});

  @override
  State<Addresschange> createState() => _AddresschangeState();
}

class _AddresschangeState extends State<Addresschange> {
  final _newEmailController = TextEditingController();

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  /// メールアドレス変更処理
  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    final newEmail = _newEmailController.text.trim();

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正しいメールアドレスを入力してください')),
      );
      return;
    }

    try {
      await user?.verifyBeforeUpdateEmail(newEmail);

      // 成功メッセージ
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('確認メールを送信しました'),
            content: Text(
              '新しいメールアドレス「$newEmail」宛に確認メールを送信しました。\n'
              'メール内のリンクをクリックして変更を完了してください。',
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
      if (e.code == 'requires-recent-login') {
        message = '再ログインが必要です。もう一度ログインしてください。';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メールアドレス設定')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _newEmailController,
              decoration: const InputDecoration(
                labelText: '新しいメールアドレス',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changeEmail,
              child: const Text('メールアドレスを変更'),
            ),
          ],
        ),
      ),
    );
  }
}
