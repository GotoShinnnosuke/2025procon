import 'package:flutter/material.dart';
import 'fitnessDetail.dart';
import 'models/training_menu.dart';
import 'services/ai_service.dart';
import 'login/account.dart';
import 'login/mypage.dart';
import 'login/auth.dart';

void main() {
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4); // やや青みのあるパープル
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: null,
      ),
      home: const _AuthGate(),
      routes: {
        '/home': (_) => const HomePage(),
        '/auth': (_) => const AuthLandingPage(),
        '/mypage': (_) => const MyPage(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthRepository().isLoggedIn(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loggedIn = snap.data ?? false;
        return loggedIn ? const HomePage() : const AuthLandingPage();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _searchController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<TrainingMenu> _plans = [];
  late final AIServiceBase _ai;

  @override
  void initState() {
    super.initState();
    final key = const String.fromEnvironment('OPENAI_API_KEY');
    _ai = OpenAIAIService(apiKey: key);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = '条件を入力してください（目的、頻度、時間、器具など）';
        _plans = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _plans = [];
    });
    try {
      final hint = '以下の条件から3つのトレーニングプランをJSONで作成: ';
      final plans = await _ai.generatePlans('$hint$input');
      setState(() => _plans = plans);
    } catch (e) {
      final msg = e is AIServiceException
          ? e.message
          : '生成に失敗しました。しばらくして再試行してください。';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(
                controller: _searchController,
                onSearch: _onSearch,
              ),
              const SizedBox(height: 16),
              if (_loading) ...[
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                )),
              ] else if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ] else if (_plans.isNotEmpty) ...[
                Text(
                  'AI提案メニュー',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2A37),
                      ),
                ),
                const SizedBox(height: 12),
                _ListCard(children: [
                  for (final p in _plans)
                    _TrainingTile(
                      color: const Color(0xFFEFF8E7),
                      iconColor: const Color(0xFF16A34A),
                      icon: Icons.list_alt,
                      title: p.name,
                      subtitle1: '${p.daysPerWeek ?? '-'}日/週・${p.durationWeeks ?? '-'}週｜${p.intensity ?? '—'}',
                      subtitle2: p.summary ?? '',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FitnessDetailPage(plan: p),
                          ),
                        );
                      },
                    ),
                ]),
                const SizedBox(height: 16),
              ],
              Text(
                'おすすめトレーニング',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2A37),
                    ),
              ),
              const SizedBox(height: 12),
              _ListCard(children: [
                _TrainingTile(
                  color: Color(0xFFE9E3FF),
                  iconColor: Color(0xFF6C63FF),
                  icon: Icons.fitness_center,
                  title: '筋力強化プログラム',
                  subtitle1: '15分・初級者向け',
                  subtitle2: 'お腹周りを効率的に鍛える基本メニュー',
                  calories: 100,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FitnessDetailPage(),
                      ),
                    );
                  },
                ),
                _TrainingTile(
                  color: Color(0xFFE6F4FF),
                  iconColor: Color(0xFF39A3F2),
                  icon: Icons.directions_run,
                  title: '有酸素運動コース',
                  subtitle1: '20分・中級者向け',
                  subtitle2: '脂肪燃焼に効果的な有酸素運動',
                  calories: 160,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FitnessDetailPage(),
                      ),
                    );
                  },
                ),
                _TrainingTile(
                  color: Color(0xFFFBE9E6),
                  iconColor: Color(0xFFF08A73),
                  icon: Icons.accessibility_new,
                  title: '下半身強化',
                  subtitle1: '25分・上級者向け',
                  subtitle2: '太ももとお尻を集中的に鍛える',
                  calories: 200,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FitnessDetailPage(),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 16),
              Text(
                '部位別メニュー',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2A37),
                    ),
              ),
              const SizedBox(height: 12),
              _CategoryRow(
                categories: const [
                  _CategoryItemData('胸', Icons.fitness_center, Color(0xFFE9E3FF)),
                  _CategoryItemData('背中', Icons.self_improvement, Color(0xFFE6F4FF)),
                  _CategoryItemData('脚', Icons.directions_walk, Color(0xFFFBE9E6)),
                  _CategoryItemData('体幹', Icons.accessibility, Color(0xFFEFF8E7)),
                ],
              ),
              const SizedBox(height: 24),
              // 下余白
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyPage()),
            );
            return;
          }
          setState(() => _currentIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'カレンダー'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.controller,
    required this.onSearch,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'generateTraining',
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日のトレーニング',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '目標に合わせたメニューを見つけよう',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: '鍛えたい部位やトレーニング名を入力',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('検索'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC2C2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF7F1D1D)),
            ),
          ),
        ],
      ),
    );
  }
}


class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ]
        ],
      ),
    );
  }
}

class _TrainingTile extends StatelessWidget {
  const _TrainingTile({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle1,
    required this.subtitle2,
    this.onTap,
    this.calories,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle1;
  final String subtitle2;
  final VoidCallback? onTap;
  final int? calories; // 想定消費カロリー（kcal）

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF111827)),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle1,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle2,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            if (calories != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Text(
                    '想定消費カロリー ${calories}kcal',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
      onTap: onTap,
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.categories});
  final List<_CategoryItemData> categories;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final c in categories)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _CategoryItem(data: c),
            ),
          ),
      ],
    );
  }
}

class _CategoryItemData {
  final String label;
  final IconData icon;
  final Color color;
  const _CategoryItemData(this.label, this.icon, this.color);
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({required this.data});
  final _CategoryItemData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: data.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: const Color(0xFF374151)),
            ),
            const SizedBox(height: 8),
            Text(
              data.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
            ),
          ],
        ),
      ),
    );
  }
}
