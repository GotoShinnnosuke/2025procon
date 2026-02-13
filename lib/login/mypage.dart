import 'dart:typed_data';

import 'package:fitness/fitnessDetail.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'auth.dart';
import '../services/user_profile_repository.dart';
import 'security.dart';
import 'addresschange.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'user');
  final _emailController = TextEditingController();
  final _ageController = TextEditingController(text: '20');
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '55');
  final _passwordController = TextEditingController(text: '123456');

  final _picker = ImagePicker();
  Uint8List? _avatarBytes;
  String? _avatarUrl;
  bool _avatarUploading = false;

  @override
  void initState() {
    super.initState();
    _prefillFromCache();
  }

  Future<void> _prefillFromCache() async {
    final user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic>? firestore;
    if (user != null) {
      firestore = await UserProfileRepository().getProfile(user.uid);
    }
    final prof = await AuthRepository().getProfile();
    final name = (firestore?['name'] as String?) ?? (prof['name'] as String?);
    final email =
        (firestore?['email'] as String?) ?? user?.email ?? (prof['email'] as String?);
    final age = (firestore?['age'] as int?) ?? (prof['age'] as int?);
    final h = (firestore?['height'] as num?)?.toDouble() ?? (prof['height'] as double?);
    final w = (firestore?['weight'] as num?)?.toDouble() ?? (prof['weight'] as double?);
    final avatar =
        (firestore?['avatarUrl'] as String?) ?? (prof['avatarUrl'] as String?);
    if (!mounted) return;
    setState(() {
      if (name != null && name.isNotEmpty) _nameController.text = name;
      _emailController.text = email ?? '';
      if (age != null) _ageController.text = '$age';
      if (h != null) {
        _heightController.text =
            h.toStringAsFixed(h.truncateToDouble() == h ? 0 : 1);
      }
      if (w != null) {
        _weightController.text =
            w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1);
      }
      _avatarUrl = avatar;
    });
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _avatarBytes = bytes);
  }

  Future<String?> _uploadAvatar(String uid, Uint8List bytes) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile-images/$uid/avatar.png');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    return ref.getDownloadURL();
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
      String? avatarUrl = _avatarUrl;
      if (_avatarBytes != null) {
        setState(() => _avatarUploading = true);
        try {
          avatarUrl = await _uploadAvatar(user.uid, _avatarBytes!);
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            await NetworkImage(avatarUrl).evict();
          }
          _avatarUrl = avatarUrl;
          _avatarBytes = null;
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('アイコンの保存に失敗しました')),
          );
        } finally {
          if (mounted) setState(() => _avatarUploading = false);
        }
      }
      await UserProfileRepository().updateProfile(
        uid: user.uid,
        name: _nameController.text,
        email: user.email,
        age: int.tryParse(_ageController.text),
        height: double.tryParse(_heightController.text),
        weight: double.tryParse(_weightController.text),
        avatarUrl: avatarUrl,
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
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
    _emailController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        (_avatarUrl != null && _avatarUrl!.isNotEmpty) ? _avatarUrl : null;
    final ImageProvider<Object>? avatarProvider;
    if (_avatarBytes != null) {
      avatarProvider = MemoryImage(_avatarBytes!);
    } else if (avatarUrl != null) {
      avatarProvider = NetworkImage(avatarUrl);
    } else {
      avatarProvider = null;
    }
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
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.deepPurple,
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.white)
                          : null,
                    ),
                    if (_avatarUploading)
                      const Positioned(
                        bottom: 6,
                        right: 6,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.photo_camera, size: 18),
                            onPressed: _pickAvatar,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('アイコンを変更'),
                ),
                const SizedBox(height: 16),
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
                  controller: _emailController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
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
                    backgroundColor: const Color(0xFFFFF1F1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Addresschange()),
                  ),
                  child:
                      const Text('メールアドレスの変更', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SecurityPage()),
                  ),
                  child: const Text('パスワードの変更', style: TextStyle(fontSize: 20)),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
