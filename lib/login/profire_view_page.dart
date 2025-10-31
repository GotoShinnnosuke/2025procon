import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mypage.dart';
import 'auth.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _newEmailController = TextEditingController();
  String? _name;
  String? _email;
  int? _age;
  double? _height;
  double? _weight;

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthRepository().getProfile();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _name = (profile['name'] as String?) ?? user?.displayName;
      _email = (profile['email'] as String?) ?? user?.email;
      _age = profile['age'] as int?;
      _height = profile['height'] as double?;
      _weight = profile['weight'] as double?;
    });
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
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const CircleAvatar(
                  radius: 34,
                  child: Icon(Icons.person, size: 34),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(_email ?? '-', style: const TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyPage()),
                    ).then((_) => _loadProfile());
                  },
                  child: const Text('プロフィールを編集'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoTile('年齢', _age?.toString() ?? '-'),
            _infoTile('身長', _height != null ? '${_height!.toStringAsFixed(1)} cm' : '-'),
            _infoTile('体重', _weight != null ? '${_weight!.toStringAsFixed(1)} kg' : '-'),
            const SizedBox(height: 24),
            const Text('メール設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
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
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(color: Color(0xFF374151))),
        ],
      ),
    );
  }
}
