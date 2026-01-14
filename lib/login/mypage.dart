import 'package:fitness/fitnessDetail.dart';
import 'package:flutter/material.dart';
import 'auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_profile_repository.dart';
import 'security.dart';
import 'addresschange.dart';
import '../share/share_button.dart';
import '../share/share_templates.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'user');
  final _ageController = TextEditingController(text: '20');
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '55');
  final _passwordController = TextEditingController(text: '123456');

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _prefillFromCache();
  }

  Future<void> _prefillFromCache() async {
    final prof = await AuthRepository().getProfile();
    setState(() {
      _nameController.text = (prof['name'] as String?) ?? _nameController.text;
      final age = prof['age'] as int?;
      if (age != null) _ageController.text = '$age';
      final h = prof['height'] as double?;
      if (h != null) _heightController.text = h.toStringAsFixed(h.truncateToDouble() == h ? 0 : 1);
      final w = prof['weight'] as double?;
      if (w != null) _weightController.text = w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1);
    });
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログイン状態を確認してください')),
      );
      return;
    }
    try {
      await UserProfileRepository().updateProfile(
        uid: user.uid,
        name: _nameController.text,
        age: int.tryParse(_ageController.text),
        height: double.tryParse(_heightController.text),
        weight: double.tryParse(_weightController.text),
      );
      // ローカルキャッシュも更新
      await AuthRepository().saveProfile(
        name: _nameController.text,
        age: int.tryParse(_ageController.text) ?? 0,
        height: double.tryParse(_heightController.text) ?? 0,
        weight: double.tryParse(_weightController.text) ?? 0,
        userId: user.uid,
        password: _passwordController.text,
        email: user.email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを保存しました')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました。ネットワークを確認してください')),
      );
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
      appBar: AppBar(
        title: const Text('マイページ'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '名前',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? '名前を入力してください' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '年齢',
                    prefixIcon: Icon(Icons.cake),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '年齢を入力してください';
                    if (int.tryParse(value) == null) return '数字で入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '身長 (cm)',
                    prefixIcon: Icon(Icons.height),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '身長を入力してください';
                    if (double.tryParse(value) == null) return '数値で入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '体重 (kg)',
                    prefixIcon: Icon(Icons.monitor_weight),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '体重を入力してください';
                    if (double.tryParse(value) == null) return '数値で入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _saveProfile,
                  child: const Text('プロフィールを保存',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () async {
                    await AuthRepository().logout();
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/auth', (route) => false);
                  },
                  child: const Text('ログアウト',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                //メアドの変更リンク
                const SizedBox(height: 8), 
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Addresschange()),
                    ),
                    child: const Text(
                      'メールアドレスの変更はこちら',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                // 2. パスワードの変更リンク (TextButton / 右寄せ)
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SecurityPage()),
                    ),
                    child: const Text(
                      'パスワードの変更はこちら',
                      style: TextStyle(
                        fontSize: 16, // フォントサイズを20から16に変更
                      ),
                    ),
                  ),
                ),
                // シェアボタン
                const SizedBox(height: 20),
                ShareButton(
                  data: ShareTemplates.plain(
                    message: 'マイページからX直行テスト',
                    //URL追加予定
                  ),
                  xDirect: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
