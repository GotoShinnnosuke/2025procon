import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'fitnessDetail.dart';
import 'models/training_menu.dart';
import 'services/ai_service.dart';
import 'login/account.dart';
import 'login/mypage.dart';
import 'login/profire_view_page.dart';
import 'login/auth.dart';
import 'calender/calendar_screen.dart';
import 'services/history.dart';
import 'services/favorites.dart';
import 'login/profile_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // すでに初期化済みなど、起動継続に支障ない場合は握りつぶす
  }
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
      home: const LoginPage(),
      routes: {
        '/home': (_) => const HomePage(),
        '/auth': (_) => const LoginPage(),
        '/mypage': (_) => const MyPage(),
        '/calendar': (_) => const CalendarScreen(),
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
        return loggedIn ? const HomePage() : const LoginPage();
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
  List<ExerciseItem> _exercises = [];
  late final AIServiceBase _ai;
  int _loadLevelIndex = 1; // 0:小,1:中,2:大
  List<ExerciseItem> _lastExercises = [];
  List<ExerciseItem> _favorites = [];
  String _displayName = '';
  bool _listeningProfile = false;

  @override
  void initState() {
    super.initState();
    final key = const String.fromEnvironment('OPENAI_API_KEY');
    _ai = OpenAIAIService(apiKey: key);
    _loadLastExercises();
    _loadFavorites();
    _loadDisplayName();
    if (!_listeningProfile) {
      ProfileNotifier.instance.addListener(_loadDisplayName);
      _listeningProfile = true;
    }
  }

  Future<void> _loadLastExercises() async {
    final repo = HistoryRepository();
    final last = await repo.getLastExercises();
    if (!mounted) return;
    setState(() => _lastExercises = last);
  }

  Future<void> _loadFavorites() async {
    final repo = FavoritesRepository();
    final favs = await repo.getFavorites();
    if (!mounted) return;
    setState(() => _favorites = favs);
  }

  Future<void> _loadDisplayName() async {
    final prof = await AuthRepository().getProfile();
    final name = (prof['name'] as String?)?.trim();
    final email = (prof['email'] as String?)?.trim();
    if (!mounted) return;
    setState(() => _displayName =
        (name != null && name.isNotEmpty) ? name : (email ?? 'ゲスト'));
  }

  Future<void> _addDemoExercise() async {
    final demo = ExerciseItem(
      name: 'テスト種目 (3秒×2セット)',
      sets: 2,
      repsOrSeconds: '3秒',
      rest: '10秒',
      notes: '動作確認用のテスト種目です',
      tips: const ['カウントは声に出してもOK', 'フォームよりも動作確認を優先'],
      steps: const ['姿勢を作る', '3秒キープ', 'リラックス'],
    );
    setState(() {
      _loading = false;
      _error = null;
      _exercises = [demo];
    });
    await HistoryRepository().saveLastExercises([demo]);
    if (mounted) setState(() => _lastExercises = [demo]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_listeningProfile) {
      ProfileNotifier.instance.removeListener(_loadDisplayName);
      _listeningProfile = false;
    }
    super.dispose();
  }

  Future<void> _onSearch() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = '条件を入力してください（目的、頻度、時間、器具など）';
        _exercises = [];
      });
      return;
    }
    final loadLabel = ['小', '中', '大'][_loadLevelIndex];
    final loadHint = _loadLevelIndex == 0
        ? '低強度（初心者・関節に優しい）'
        : _loadLevelIndex == 1
            ? '中強度（標準的な負荷）'
            : '高強度（上級者向け・注意事項必須）';
    setState(() {
      _loading = true;
      _error = null;
      _exercises = [];
    });
    try {
      final hint =
          '以下のユーザー入力と選択された負荷(${loadLabel}: ${loadHint})に合わせ、必ず各プランに具体的な種目(exercises)を含む3つの提案をJSONで作成してください。';
      // 種目リストのみを生成
      final exercises = await _ai.generateExercises(
        '次の条件に合う具体的な種目のみのリストをJSONで返してください（フォーマット: {"exercises":[{name,sets,repsOrSeconds,rest,notes,calories,tips:[string],steps:[string]}]}）。器具は使用不可（自重のみ）。ダンベル/バーベル/マシン/ケトルベル/チューブ等は不可。各種目に推定消費カロリー(calories: 整数,kcal)を必ず含めてください。\n'
        '$hint\nユーザー入力: $input\n希望負荷: ${loadLabel}',
      );
      setState(() => _exercises = exercises);
      // 履歴として保存
      await HistoryRepository().saveLastExercises(exercises);
      if (mounted) {
        setState(() => _lastExercises = exercises);
      }
    } catch (e) {
      final msg =
          e is AIServiceException ? e.message : '生成に失敗しました。しばらくして再試行してください。';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_currentIndex == 0) {
      body = _buildHomeBody(context);
    } else if (_currentIndex == 1) {
      body = const CalendarScreen();
    } else {
      body = const ProfileView();
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'カレンダー',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'マイページ',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_displayName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'こんにちは、$_displayName さん',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                ),
              ),
            _HeaderCard(
              controller: _searchController,
              onSearch: _onSearch,
              loadLevelIndex: _loadLevelIndex,
              onSelectLoad: (i) => setState(() => _loadLevelIndex = i),
              onAddDemo: _addDemoExercise,
            ),
            const SizedBox(height: 16),
            if (_loading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ] else if (_exercises.isNotEmpty) ...[
              Text(
                'AI提案 種目リスト',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2A37),
                    ),
              ),
              const SizedBox(height: 12),
              _ListCard(
                children: [
                  for (final ex in _exercises)
                    _TrainingTile(
                      color: const Color(0xFFEFF8E7),
                      iconColor: const Color(0xFF16A34A),
                      icon: Icons.fitness_center,
                      title: ex.name,
                      subtitle1:
                          'セット: ${ex.sets ?? '-'}  回数/秒数: ${ex.repsOrSeconds ?? '-'}',
                      subtitle2:
                          (ex.notes ?? '').isEmpty ? '—' : (ex.notes ?? ''),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FitnessDetailPage(exercise: ex),
                          ),
                        ).then((_) => _loadFavorites());
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'お気に入りのトレーニング',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2A37),
                  ),
            ),
            const SizedBox(height: 12),
            if (_favorites.isEmpty)
              const Text(
                'お気に入り登録された種目はまだありません。',
                style: TextStyle(color: Color(0xFF6B7280)),
              )
            else
              _ListCard(
                children: [
                  for (final ex in _favorites)
                    _TrainingTile(
                      color: const Color(0xFFE9E3FF),
                      iconColor: const Color(0xFF6C63FF),
                      icon: Icons.favorite,
                      title: ex.name,
                      subtitle1:
                          'セット: ${ex.sets ?? '-'}  回数/秒数: ${ex.repsOrSeconds ?? '-'}',
                      subtitle2:
                          (ex.notes ?? '').isEmpty ? '—' : (ex.notes ?? ''),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FitnessDetailPage(exercise: ex),
                          ),
                        ).then((_) => _loadFavorites());
                      },
                    ),
                ],
              ),
            const SizedBox(height: 24),
            Text(
              '前回のトレーニング',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2A37),
                  ),
            ),
            const SizedBox(height: 12),
            if (_lastExercises.isEmpty)
              const Text(
                'まだ前回のトレーニングはありません。検索して提案を生成しましょう。',
                style: TextStyle(color: Color(0xFF6B7280)),
              )
            else
              _ListCard(
                children: [
                  for (final ex in _lastExercises)
                    _TrainingTile(
                      color: const Color(0xFFE6F4FF),
                      iconColor: const Color(0xFF39A3F2),
                      icon: Icons.fitness_center,
                      title: ex.name,
                      subtitle1:
                          'セット: ${ex.sets ?? '-'}  回数/秒数: ${ex.repsOrSeconds ?? '-'}',
                      subtitle2:
                          (ex.notes ?? '').isEmpty ? '—' : (ex.notes ?? ''),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FitnessDetailPage(exercise: ex),
                          ),
                        );
                      },
                    ),
                ],
              ),
            const SizedBox(height: 24),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.controller,
    required this.onSearch,
    required this.loadLevelIndex,
    required this.onSelectLoad,
    required this.onAddDemo,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final int loadLevelIndex; // 0:小,1:中,2:大
  final ValueChanged<int> onSelectLoad;
  final VoidCallback onAddDemo;

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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
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
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.4,
                      ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('検索'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onAddDemo,
                  icon: const Icon(Icons.flash_on_outlined, size: 18),
                  label: const Text('デモ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LoadChip(
                label: '負荷: 小',
                selected: loadLevelIndex == 0,
                color: const Color(0xFF10B981),
                onTap: () => onSelectLoad(0),
              ),
              const SizedBox(width: 8),
              _LoadChip(
                label: '負荷: 中',
                selected: loadLevelIndex == 1,
                color: const Color(0xFFF59E0B),
                onTap: () => onSelectLoad(1),
              ),
              const SizedBox(width: 8),
              _LoadChip(
                label: '負荷: 大',
                selected: loadLevelIndex == 2,
                color: const Color(0xFFEF4444),
                onTap: () => onSelectLoad(2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadChip extends StatelessWidget {
  const _LoadChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? color.darken() : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Color {
  Color darken([double amount = .2]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
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
          ],
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
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: Color(0xFF111827),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle1,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
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
                  const Icon(
                    Icons.local_fire_department,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '想定消費カロリー ${calories}kcal',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
