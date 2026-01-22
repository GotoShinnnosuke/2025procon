import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mypage.dart';
import 'auth.dart';
import '../banner/custom_banner.dart';
import '../services/user_profile_repository.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic>? firestore;
    if (user != null) {
      firestore = await UserProfileRepository().getProfile(user.uid);
    }
    final cache = await AuthRepository().getProfile();
    setState(() {
      _name = (firestore?['name'] as String?) ?? (cache['name'] as String?) ?? user?.displayName;
      _email = (firestore?['email'] as String?) ?? (cache['email'] as String?) ?? user?.email;
      _age = (firestore?['age'] as int?) ?? (cache['age'] as int?);
      _height = (firestore?['height'] as num?)?.toDouble() ?? (cache['height'] as double?);
      _weight = (firestore?['weight'] as num?)?.toDouble() ?? (cache['weight'] as double?);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. メインのスクロールコンテンツ
          RefreshIndicator(
            onRefresh: _loadProfile,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                // ユーザー基本情報エリア
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
                          Text(_name ?? '-',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(_email ?? '-',
                              style: const TextStyle(color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    // プロフィール編集ボタン（右上）
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
                
                // 各種ステータス表示
                _infoTile('年齢', _age?.toString() ?? '-'),
                _infoTile('身長', _height != null ? '${_height!.toStringAsFixed(1)} cm' : '-'),
                _infoTile('体重', _weight != null ? '${_weight!.toStringAsFixed(1)} kg' : '-'),

                // --- 修正ポイント：ログアウトボタンを体重タイルの下に配置 ---
                const SizedBox(height: 30), // 体重タイルとの余白
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white, // 文字色を白に指定
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () async {
                      await AuthRepository().logout();
                      if (!mounted) return;
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/auth', (route) => false);
                    },
                    child: const Text(
                      'ログアウト',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // ----------------------------------------------------

                // 下部バナーに被らないようにするための大きな余白
                const SizedBox(height: 140),
              ],
            ),
          ),

          // 2. 下部の浮かせるバナー
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: CustomBanner(
              title: "心のダンベル発売予定!!!",
              onTap: () {
                print("バナーがクリックされました");
              },
            ),
          ),
        ],
      ),
    );
  }

  // タイル表示用の共通ウィジェット
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