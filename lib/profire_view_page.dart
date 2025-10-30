import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mypage.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
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
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('確認メールを送信しました'),
          content: Text('新しいメールアドレス「$newEmail」宛に確認メールを送信しました。'
              '\nメール内のリンクをクリックして変更を完了してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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
      appBar: AppBar(
        title: const Text('プロフィール'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('ここにプロフィール情報を表示'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyPage()),
                  );
                },
                child: const Text('プロフィールを編集'),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _newEmailController,
                decoration: const InputDecoration(
                  labelText: '新しいメールアドレス',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _changeEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('メールアドレスを変更'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
