import 'package:fitness/login/newac.dart';
import 'package:flutter/material.dart';
import 'auth.dart';
import 'forget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_profile_repository.dart';

// =========================
// ログイン
// =========================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController(); // メールアドレスも可
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // デモ用の初期値をセット（毎回入力不要）
    _idController.text = 'demo';
    _passwordController.text = '123456';
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final input = _idController.text.trim();
      try {
        if (input.contains('@')) {
          // Firebase Authでログイン（メール/パスワード）
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: input,
            password: _passwordController.text,
          );
          final user = cred.user;
          if (user != null && !user.emailVerified) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('メールアドレスが未確認です。受信メールのリンクから確認してください。')),
            );
          }
          // Firestoreプロフィールを取得してローカルにキャッシュ
          if (user != null) {
            final prof = await UserProfileRepository().getProfile(user.uid);
            if (prof != null) {
              await AuthRepository().saveProfile(
                name: (prof['name'] as String?) ?? user.displayName ?? '',
                age: (prof['age'] as int?) ?? 0,
                height: (prof['height'] as num?)?.toDouble() ?? 0,
                weight: (prof['weight'] as num?)?.toDouble() ?? 0,
                userId: user.uid,
                password: _passwordController.text,
                email: (prof['email'] as String?) ?? input,
              );
            } else {
              await AuthRepository()
                  .setLoggedInUser(userId: user.uid, email: input);
            }
          }
          if (!mounted) return;
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        } else {
          // 既存のローカルIDログイン（デモ用途）
          final ok = await AuthRepository()
              .login(userId: input, password: _passwordController.text);
          if (!mounted) return;
          if (ok) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('ID: $input でログインしました')));
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('IDまたはパスワードが正しくありません')));
          }
        }
      } on FirebaseAuthException catch (e) {
        String msg = 'ログインに失敗しました';
        if (e.code == 'user-not-found') msg = 'ユーザーが見つかりません';
        if (e.code == 'wrong-password') msg = 'パスワードが違います';
        if (e.code == 'invalid-email') msg = 'メールアドレスの形式が正しくありません';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _demoLogin() async {
    // デモプロフィールを保存してそのままログイン状態にする
    final repo = AuthRepository();
    await repo.saveProfile(
      name: 'demo',
      age: 25,
      height: 170.0,
      weight: 65.0,
      userId: 'demo',
      password: '123456',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('デモユーザーでログインしました')),
    );
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('ログイン'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _idController,
                        decoration: const InputDecoration(
                          labelText: 'ユーザーID',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'IDを入力してください'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'パスワード',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'パスワードを入力してください';
                          if (value.length < 6) return '6文字以上で入力してください';
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _login,
                        child: const Text('ログイン',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterPage()),
                            );
                          },
                          child: const Text('ユーザー登録はこちら'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ForgetPage()),
                            );
                          },
                          child: const Text('パスワードをお忘れの方はこちら'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _demoLogin,
                        icon: const Icon(Icons.flash_on_outlined),
                        label: const Text('デモでログイン（ワンタップ）'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
