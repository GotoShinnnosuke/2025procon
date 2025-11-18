import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart'; // ← Firebase設定ファイルを忘れずに！

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Firebase設定
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ForgetPage(),
    );
  }
}

class ForgetPage extends StatefulWidget {
  const ForgetPage({super.key});

  @override
  State<ForgetPage> createState() => _ForgetPageState();
}

class _ForgetPageState extends State<ForgetPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// パスワードリセットメール送信処理
  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアドレスを入力してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('メールを送信しました'),
          content: Text('パスワードリセット用リンクを $email に送信しました。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'エラーが発生しました';
      if (e.code == 'user-not-found') {
        message = 'このメールアドレスは登録されていません';
      } else if (e.code == 'invalid-email') {
        message = 'メールアドレスの形式が正しくありません';
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('送信に失敗しました'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パスワードをリセット'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '登録したメールアドレスを入力してください。',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendResetLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 63, 169, 132),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '送信',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
