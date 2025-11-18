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
    _idController.text = 'demo@example.com'; // メール形式に修正
    _passwordController.text = '123456';
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _idController.text.trim();
      try {
        // メール/パスワードでログイン
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
        final user = cred.user;

        if (user == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ログインに失敗しました。もう一度お試しください。')),
          );
          return;
        }

        // メール未確認のチェック（ログインが成功した後に実行）
        if (!user.emailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('メールアドレスが未確認です。受信メールのリンクから確認してください。')),
          );
        }

        // ログイン状態を記録（簡易キャッシュ）
        await AuthRepository().setLoggedInUser(userId: user.uid, email: email);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } on FirebaseAuthException catch (e) {
        String msg = 'ログインに失敗しました';
        // Firebaseエラーコードに基づいたメッセージ
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
            msg = 'ユーザーが見つからないか、メールアドレス/パスワードが違います';
        } else if (e.code == 'wrong-password') {
            msg = 'パスワードが違います'; 
        } else if (e.code == 'invalid-email') {
            msg = 'メールアドレスの形式が正しくありません';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _demoLogin() async {
    // デモプロフィールを保存してそのままログイン状態にする
    final repo = AuthRepository();
    // ダミーのユーザーIDと情報でプロファイルを保存
    await repo.saveProfile(
      name: 'デモユーザー',
      age: 25,
      height: 170.0,
      weight: 65.0,
      userId: 'demo', // デモユーザーのIDを固定
      password: '123456', // ダミーのパスワード
    );
    // ログイン状態を記録
    await repo.setLoggedInUser(userId: 'demo', email: 'demo@example.com');

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
                    mainAxisSize: MainAxisSize.min, // コンテンツに応じてサイズを調整
                    children: [
                      // メールアドレス/ID入力欄
                      TextFormField(
                        controller: _idController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'メールアドレス',
                          hintText: 'example@example.com',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'メールアドレスを入力してください'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // パスワード入力欄
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
                      // ログインボタン
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 63, 169, 132),
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
                      // パスワードリセットリンク
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
                          child: const Text('パスワードをお忘れの方はこちら', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 新規登録リンク
                      Align(
                        alignment: Alignment.centerRight,
                          child:TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterPage()),
                          );
                        },
                        child: const Text('新規登録はこちら', style: TextStyle(fontSize: 16)),
                      ),
                      ),
                      const SizedBox(height: 12),
                      // デモログインボタン
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