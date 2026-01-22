import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mypage.dart';
import 'auth.dart';
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
  String? _avatarUrl;

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
      _avatarUrl = (firestore?['avatarUrl'] as String?) ?? (cache['avatarUrl'] as String?);
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        (_avatarUrl != null && _avatarUrl!.isNotEmpty) ? _avatarUrl : null;
    final avatarProvider =
        avatarUrl != null ? NetworkImage(avatarUrl) : null;
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
                CircleAvatar(
                  radius: 34,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? const Icon(Icons.person, size: 34)
                      : null,
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
                ElevatedButton(
                  onPressed: () {
                    Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (context) => const MyPage()),
                    ).then((saved) {
                      _loadProfile();
                      if (saved == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('プロフィールを保存しました')),
                        );
                      }
                    });
                  },
                  child: const Text('プロフィールを編集'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoTile('年齢', _age?.toString() ?? '-'),
            _infoTile('身長',
                _height != null ? '${_height!.toStringAsFixed(1)} cm' : '-'),
            _infoTile('体重',
                _weight != null ? '${_weight!.toStringAsFixed(1)} kg' : '-'),
            const SizedBox(height: 24),
            const _DumbbellAdBanner(),
            const SizedBox(height: 8),
            const SizedBox(height: 10),
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

class _DumbbellAdBanner extends StatelessWidget {
  const _DumbbellAdBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          debugPrint('ダンベル広告タップ');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center,
                    color: Color(0xFF6B7280), size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '自宅トレ用ダンベルセット',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '省スペースで気軽に筋トレ。'
                      '負荷調整が簡単で初心者にもおすすめ。',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Icon(Icons.chevron_right, color: Colors.black54),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
