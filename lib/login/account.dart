import 'package:flutter/material.dart';
import 'auth.dart';
import 'forget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_profile_repository.dart';

// 認証ランディング: 登録 or ログイン選択
class AuthLandingPage extends StatelessWidget {
  const AuthLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('アカウント')), 
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              ),
              child: const Text('ユーザー登録を開始', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF1F1),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
              child: const Text('ログインページへ', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// ユーザー登録ページ
// =========================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // デモ用の初期値をセット（毎回入力不要）
    _nameController.text = 'demo';
    _emailController.text = 'demo@example.com';
    _ageController.text = '25';
    _heightController.text = '170';
    _weightController.text = '65';
    _passwordController.text = '123456';
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('登録内容確認'),
          content: Text('''
名前: ${_nameController.text}
メール: ${_emailController.text}
年齢: ${_ageController.text}
身長: ${_heightController.text} cm
体重: ${_weightController.text} kg
'''),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('戻る')),
            TextButton(onPressed: _saveProfile, child: const Text('登録')),
          ],
        ),
      );
    }
  }

  void _saveProfile() async {
    Navigator.pop(context); // 確認ダイアログを閉じる
    try {
      // Firebase Auth でユーザー作成
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await cred.user?.sendEmailVerification();

      // Firestoreにプロフィール保存（UIDを主キー）
      final uid = cred.user!.uid;
      try {
        await UserProfileRepository().setProfile(
          uid: uid,
          name: _nameController.text,
          email: _emailController.text.trim(),
          age: int.parse(_ageController.text),
          height: double.parse(_heightController.text),
          weight: double.parse(_weightController.text),
        );
      } catch (e) {
        // Firestore保存に失敗した場合でも、ローカル保存と画面遷移は継続
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('プロフィールの保存に失敗しました（オフライン保存のみ）。後で再試行してください。')),
          );
        }
      }

      // ローカルにもキャッシュ（ログイン状態にはしない）
      await AuthRepository().saveProfile(
        name: _nameController.text,
        age: int.parse(_ageController.text),
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        userId: uid,
        password: _passwordController.text,
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      // 確認メールの案内を出しつつホームへ遷移
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('確認メールを送信しました: ${_emailController.text.trim()}')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      String msg = '登録に失敗しました';
      if (e.code == 'email-already-in-use') msg = 'このメールアドレスは既に登録されています';
      if (e.code == 'invalid-email') msg = 'メールアドレスの形式が正しくありません';
      if (e.code == 'weak-password') msg = 'パスワードが弱すぎます（6文字以上推奨）';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('ユーザー登録'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'メールアドレス',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'メールアドレスを入力してください';
                          if (!value.contains('@')) return '正しいメール形式を入力してください';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '名前(ID)',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty ? '名前を入力してください' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(
                          labelText: '年齢',
                          prefixIcon: Icon(Icons.cake),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return '年齢を入力してください';
                          if (int.tryParse(value) == null) return '数字で入力してください';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _heightController,
                        decoration: const InputDecoration(
                          labelText: '身長 (cm)',
                          prefixIcon: Icon(Icons.height),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return '身長を入力してください';
                          if (double.tryParse(value) == null) return '数値で入力してください';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _weightController,
                        decoration: const InputDecoration(
                          labelText: '体重 (kg)',
                          prefixIcon: Icon(Icons.monitor_weight),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return '体重を入力してください';
                          if (double.tryParse(value) == null) return '数値で入力してください';
                          return null;
                        },
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
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'パスワードを入力してください';
                          if (value.length < 6) return '6文字以上で入力してください';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 18),
          ),
          onPressed: _submitForm,
          child: const Text('登録'),
        ),
      ),
    );
  }
}

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
      final email = _idController.text.trim();
      try {
        // メール/パスワードでログインのみ許可
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
        final user = cred.user;
        if (user != null && !user.emailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('メールアドレスが未確認です。受信メールのリンクから確認してください。')),
          );
        }
        // ログイン状態を記録（簡易キャッシュ）
        await AuthRepository().setLoggedInUser(userId: user?.uid ?? email, email: email);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } on FirebaseAuthException catch (e) {
        String msg = 'ログインに失敗しました';
        if (e.code == 'user-not-found') msg = 'ユーザーが見つかりません';
        if (e.code == 'wrong-password') msg = 'パスワードが違います';
        if (e.code == 'invalid-email') msg = 'メールアドレスの形式が正しくありません';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _idController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'メールアドレス',
                          hintText: 'example@example.com',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'メールアドレスを入力してください';
                          if (!value.contains('@')) return '正しいメール形式を入力してください';
                          return null;
                        },
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
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'パスワードを入力してください';
                          if (value.length < 6) return '6文字以上で入力してください';
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _login,
                        child: const Text('ログイン', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgetPage()),
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
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
