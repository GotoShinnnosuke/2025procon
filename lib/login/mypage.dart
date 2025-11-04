import 'package:flutter/material.dart';
import 'auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_profile_repository.dart';

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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'パスワードを入力してください';
                    if (value.length < 6) return '6文字以上で入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
