import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'fitnessDetail.dart';
import 'plan_detail.dart';
import 'models/training_menu.dart';
import 'models/training_log_entry.dart';
import 'services/ai_service.dart';
import 'services/favorites.dart';
import 'services/function_endpoints.dart';
import 'banner/fake_ad_banner.dart';
import 'login/account.dart';
import 'login/mypage.dart';
import 'login/profire_view_page.dart';
import 'login/auth.dart';
import 'login/profile_notifier.dart';
import 'calender/calendar_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // すでに初期化済みなど、起動継続に支障ない場合は握りつぶす。
  }
  runApp(const FitnessApp());
}

/// アプリ全体のMaterialAppを構築するルートWidget。
class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
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

/// 起動時にログイン状態を判定して遷移先を決めるゲート。
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

/// ログイン有無でHomeかLoginを出し分けるState。
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

/// ホームタブ／カレンダー／マイページを持つメイン画面。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum TrainingGenerationMode {
  exercises,
  plans,
}

/// Homeページの状態管理（検索、AI提案、表示名など）。
class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final _searchController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<ExerciseItem> _exercises = [];
  List<TrainingMenu> _plans = [];
  List<ExerciseItem> _favorites = [];
  List<TrainingMenu> _favoritePlans = [];
  late final AIServiceBase _ai;
  int _loadLevelIndex = 1; // 0:低,1:中,2:高
  String _displayName = '';
  bool _listeningProfile = false;
  TrainingGenerationMode _generationMode = TrainingGenerationMode.exercises;
  int _planMinutes = 10;

  static const List<String> _bodyKeywords = [
    '胸',
    '背中',
    '脚',
    '足',
    '腹',
    '腹筋',
    '腕',
    '肩',
    '尻',
    'お尻',
    '体幹',
    '全身',
    '有酸素',
    'ストレッチ',
  ];
  static const List<String> _exerciseKeywords = [
    'スクワット',
    'ランジ',
    'プッシュアップ',
    '腕立て',
    'プランク',
    'クランチ',
    'ヒップリフト',
    'バックエクステンション',
    'バーピー',
    'マウンテンクライマー',
    'ディップス',
    'squat',
    'lunge',
    'push',
    'plank',
    'crunch',
    'burpee',
    'mountain',
    'dip',
  ];

  bool get _hasGeneratedResults => _exercises.isNotEmpty || _plans.isNotEmpty;

  String get _modeLabel =>
      _generationMode == TrainingGenerationMode.exercises
          ? '種目生成'
          : 'プラン生成 (${_planMinutes}分)';

  @override
  void initState() {
    super.initState();
    final key = const String.fromEnvironment('OPENAI_API_KEY');
    _ai = OpenAIAIService(
      apiKey: key,
      menuFunctionUrl: kGenerateMenuFunctionUrl,
    );
    _loadFavorites();
    _loadFavoritePlans();
    _loadDisplayName();
    if (!_listeningProfile) {
      ProfileNotifier.instance.addListener(_loadDisplayName);
      _listeningProfile = true;
    }
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

  Future<void> _loadFavorites() async {
    final repo = FavoritesRepository();
    final favs = await repo.getFavorites();
    if (!mounted) return;
    setState(() => _favorites = favs);
  }

  Future<void> _loadFavoritePlans() async {
    final repo = PlanFavoritesRepository();
    final favs = await repo.getFavorites();
    if (!mounted) return;
    setState(() => _favoritePlans = favs);
  }

  Future<void> _loadDisplayName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = doc.data()?['name'] as String?;
    final email = FirebaseAuth.instance.currentUser?.email;

    final fallback = (email != null && email.isNotEmpty)
        ? email.split('@').first
        : 'ゲスト';

    if (!mounted) return;
    setState(() {
      _displayName = (name != null && name.isNotEmpty) ? name : fallback;
    });
  }

  void _setGenerationMode(TrainingGenerationMode mode) {
    if (_generationMode == mode) return;
    setState(() {
      _generationMode = mode;
      _loading = false;
      _error = null;
      _exercises = [];
      _plans = [];
    });
  }

  void _showRegenNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('条件が変更されました。再生成をおこなってください')),
    );
  }

  void _setLoadLevel(int index) {
    if (_loadLevelIndex == index) return;
    final hadResults = _hasGeneratedResults;
    setState(() => _loadLevelIndex = index);
    if (hadResults) _showRegenNotice();
  }

  void _setPlanMinutes(int minutes) {
    if (_planMinutes == minutes) return;
    final hadResults = _hasGeneratedResults;
    setState(() => _planMinutes = minutes);
    if (hadResults) _showRegenNotice();
  }

  Stream<List<TrainingLogEntry>> _todayLogsStream(String uid) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return FirebaseFirestore.instance
        .collection('trainingLogs')
        .where('userId', isEqualTo: uid)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrainingLogEntry.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> _onSearch() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = '未入力です。部位名または種目名を入力してください。';
        _exercises = [];
        _plans = [];
      });
      return;
    }
    final normalized = input.replaceAll(RegExp(r'\s+'), '');
    if (normalized.length < 2) {
      setState(() {
        _error = '入力が短すぎます。例: 胸・背中 / スクワット・プランク';
        _exercises = [];
        _plans = [];
      });
      return;
    }
    final lower = normalized.toLowerCase();
    final matchesBody = _bodyKeywords.any((k) => normalized.contains(k));
    final matchesExercise = _exerciseKeywords.any((k) => lower.contains(k));
    if (!matchesBody && !matchesExercise) {
      setState(() {
        _error = '部位名または種目名で入力してください（例: 胸・背中 / スクワット・プランク）';
        _exercises = [];
        _plans = [];
      });
      return;
    }
    final loadLabel = ['低', '中', '高'][_loadLevelIndex];
    final loadHint = _loadLevelIndex == 0
        ? '低強度（関節に優しい）'
        : _loadLevelIndex == 1
            ? '中強度（標準的な負荷）'
            : '高強度（上級者向け）';
    setState(() {
      _loading = true;
      _error = null;
      _exercises = [];
      _plans = [];
    });
    try {
      if (_generationMode == TrainingGenerationMode.plans) {
        final prompt =
            '入力された部位を中心に鍛えられる、1回のトレーニングで完結するセットプランを3案作成してください。'
            '所要時間は${_planMinutes}分を目安にしてください。'
            '各プランは複数の種目(exercises)で構成し、1回のトレーニングとして完結する内容にしてください。'
            '各種目のsteps/tips/notesには足・手の置き方、動作方向、姿勢、呼吸、よくあるNGを短文で具体的に書いてください。'
            '週間/日数といった周期の説明は不要です。'
            '負荷は ${loadLabel}（${loadHint}）を想定。'
            'ユーザー入力: $input';
        final plans = await _ai.generatePlans(prompt);
        if (!mounted) return;
        setState(() => _plans = plans);
      } else {
        final hint =
            '以下の条件と負荷(${loadLabel}: ${loadHint})に合わせ、具体的な種目(exercises)を含む提案をJSONで作成してください。';
        final exercises = await _ai.generateExercises(
          '次の条件に合う具体的な種目のみのリストをJSONで返してください（フォーマット: {"exercises":[{name,sets,repsOrSeconds,rest,notes,calories,tips:[string],steps:[string]}]}）。器具は使用不可（自重のみ）。各種目に推定消費カロリー(calories: 整数,kcal)を必ず含めてください。\n'
          'steps/tips/notesには足・手の置き方、動作方向、姿勢、呼吸、よくあるNGを短文で具体的に書いてください。\n'
          '$hint\nユーザー入力: $input\n希望負荷: $loadLabel',
        );
        final updated =
            exercises.map((e) => e.copyWith(loadLevel: loadLabel)).toList();
        if (!mounted) return;
        setState(() => _exercises = updated);
      }
    } catch (e) {
      final msg = e is AIServiceException
          ? e.message
          : '生成に失敗しました。しばらくして再試行してください。';
      if (!mounted) return;
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FakeAdBanner(),
          NavigationBar(
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
        ],
      ),
    );
  }

  Widget _buildHomeBody(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_displayName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'こんにちは、$_displayName さん',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _modeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _HeaderCard(
              controller: _searchController,
              onSearch: _onSearch,
              loadLevelIndex: _loadLevelIndex,
              onSelectLoad: _setLoadLevel,
              mode: _generationMode,
              onModeChanged: _setGenerationMode,
              planMinutes: _planMinutes,
              onPlanMinutesChanged: _setPlanMinutes,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAiSection()),
                const SizedBox(width: 16),
                Expanded(child: _buildRightColumn()),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSection() {
    final isPlanMode = _generationMode == TrainingGenerationMode.plans;
    final title = isPlanMode ? 'AI提案 トレーニングプラン' : 'AI提案 種目リスト';
    final emptyMessage =
        isPlanMode ? 'AIにトレーニングプランを生成させよう' : 'AIにトレーニングメニューを生成させよう';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2A37),
              ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _ErrorBanner(message: _error!)
        else if (isPlanMode ? _plans.isEmpty : _exercises.isEmpty)
          _ListCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  emptyMessage,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ],
          )
        else
          _ListCard(
            children: isPlanMode
                ? [
                    for (final plan in _plans)
                      _TrainingPlanTile(
                        plan: plan,
                        minutes: _planMinutes,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlanDetailPage(
                                plan: plan,
                                minutes: _planMinutes,
                              ),
                            ),
                          ).then((_) => _loadFavoritePlans());
                        },
                      ),
                  ]
                : [
                    for (final ex in _exercises)
                      _TrainingTile(
                        color: const Color(0xFFEFF8E7),
                        iconColor: const Color(0xFF16A34A),
                        icon: Icons.fitness_center,
                        title: ex.name,
                        subtitle1:
                            'セット: ${ex.sets ?? '-'}  回数/秒数: ${ex.repsOrSeconds ?? '-'}',
                        subtitle2:
                            (ex.notes ?? '').isEmpty ? ' ' : (ex.notes ?? ''),
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
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTodayLogsSection(),
        const SizedBox(height: 16),
        _buildFavoritesSection(),
        const SizedBox(height: 16),
        _buildFavoritePlansSection(),
      ],
    );
  }

  Widget _buildFavoritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'お気に入りトレーニング',
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
                  subtitle2: (ex.notes ?? '').isEmpty ? ' ' : (ex.notes ?? ''),
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
      ],
    );
  }

  Widget _buildFavoritePlansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'お気に入りプラン',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2A37),
              ),
        ),
        const SizedBox(height: 12),
        if (_favoritePlans.isEmpty)
          const Text(
            'お気に入り登録されたプランはまだありません。',
            style: TextStyle(color: Color(0xFF6B7280)),
          )
        else
          _ListCard(
            children: [
              for (final plan in _favoritePlans)
                _TrainingPlanTile(
                  plan: plan,
                  minutes: null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlanDetailPage(plan: plan),
                      ),
                    ).then((_) => _loadFavoritePlans());
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTodayLogsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<TrainingLogEntry>>(
      stream: _todayLogsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorBanner(message: '本日の履歴取得に失敗しました: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data!;
        final visibleLogs = logs.where((log) => !log.isPlanChild).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本日のトレーニング履歴',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2A37),
                  ),
            ),
            const SizedBox(height: 12),
            if (visibleLogs.isEmpty)
              const Text(
                '本日行ったトレーニングはありません。',
                style: TextStyle(color: Color(0xFF6B7280)),
              )
            else
              _ListCard(
                children: [
                  for (final log in visibleLogs)
                    if (log.isPlan)
                      _TrainingPlanTile(
                        plan: log.toPlan(),
                        minutes: log.planMinutes,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlanDetailPage(
                                plan: log.toPlan(),
                                minutes: log.planMinutes,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      _TrainingTile(
                        color: const Color(0xFFE6F4FF),
                        iconColor: const Color(0xFF39A3F2),
                        icon: Icons.fitness_center,
                        title: log.exerciseName,
                        subtitle1:
                            'セット: ${log.sets ?? '-'}  回数/秒数: ${log.repsOrSeconds ?? '-'}  負荷: ${log.loadLevel ?? '-'}',
                        subtitle2:
                            (log.notes ?? '').isEmpty ? ' ' : (log.notes ?? ''),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FitnessDetailPage(
                                exercise: log.toExerciseItem(),
                              ),
                            ),
                          );
                        },
                      ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// 検索ボックスと負荷選択チップをまとめたカード。
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.controller,
    required this.onSearch,
    required this.loadLevelIndex,
    required this.onSelectLoad,
    required this.mode,
    required this.onModeChanged,
    required this.planMinutes,
    required this.onPlanMinutesChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final int loadLevelIndex; // 0:低,1:中,2:高
  final ValueChanged<int> onSelectLoad;
  final TrainingGenerationMode mode;
  final ValueChanged<TrainingGenerationMode> onModeChanged;
  final int planMinutes;
  final ValueChanged<int> onPlanMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPlanMode = mode == TrainingGenerationMode.plans;
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
              const Text(
                'モード',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 12),
              ToggleButtons(
                isSelected: [
                  mode == TrainingGenerationMode.exercises,
                  mode == TrainingGenerationMode.plans,
                ],
                onPressed: (index) {
                  onModeChanged(index == 0
                      ? TrainingGenerationMode.exercises
                      : TrainingGenerationMode.plans);
                },
                borderRadius: BorderRadius.circular(10),
                selectedColor: Colors.white,
                fillColor: Theme.of(context).colorScheme.primary,
                constraints:
                    const BoxConstraints(minHeight: 36, minWidth: 84),
                children: const [
                  Text('種目生成'),
                  Text('プラン生成'),
                ],
              ),
            ],
          ),
          if (isPlanMode) ...[
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Text(
                  '時間',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                _TimeChip(
                  label: '5分',
                  selected: planMinutes == 5,
                  onTap: () => onPlanMinutesChanged(5),
                ),
                _TimeChip(
                  label: '10分',
                  selected: planMinutes == 10,
                  onTap: () => onPlanMinutesChanged(10),
                ),
                _TimeChip(
                  label: '20分',
                  selected: planMinutes == 20,
                  onTap: () => onPlanMinutesChanged(20),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                '負荷',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 12),
              _LoadChip(
                label: '低',
                selected: loadLevelIndex == 0,
                color: const Color(0xFF10B981),
                onTap: () => onSelectLoad(0),
              ),
              const SizedBox(width: 8),
              _LoadChip(
                label: '中',
                selected: loadLevelIndex == 1,
                color: const Color(0xFFF59E0B),
                onTap: () => onSelectLoad(1),
              ),
              const SizedBox(width: 8),
              _LoadChip(
                label: '大',
                selected: loadLevelIndex == 2,
                color: const Color(0xFFEF4444),
                onTap: () => onSelectLoad(2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: isPlanMode
                        ? '鍛えたい部位を入力（例: 胸・背中）'
                        : '鍛えたい部位やトレーニング名を入力',
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
            ],
          ),
        ],
      ),
    );
  }
}

/// 負荷レベル選択用の小さなチップ。
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

/// プラン時間選択用の小さなチップ。
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF4338CA) : const Color(0xFF6B7280);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0E7FF) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// 色を少し暗くする拡張メソッド。
extension on Color {
  Color darken([double amount = .2]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

/// エラー内容を表示するバナー。
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

/// リストの外枠カード（区切り線付き）。
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

/// トレーニングプランの要約表示タイル。
class _TrainingPlanTile extends StatelessWidget {
  const _TrainingPlanTile({
    required this.plan,
    required this.minutes,
    this.onTap,
  });
  final TrainingMenu plan;
  final int? minutes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final exercises = plan.exercises;
    final preview = exercises.take(4).toList();
    final extra = exercises.length - preview.length;
    final summary = plan.summary ?? '';
    final intensity = plan.intensity ?? '指定なし';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF111827),
              ),
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                summary,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (minutes != null) _PlanChip(label: '目安: ${minutes}分'),
                _PlanChip(label: '負荷: $intensity'),
                if (onTap != null) const _PlanChip(label: '詳細を見る'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '種目',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            for (final ex in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '・${ex.name} (${ex.sets ?? '-'}×${ex.repsOrSeconds ?? '-'})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                ),
              ),
            if (extra > 0)
              Text(
                '他${extra}件',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            if (plan.caution != null && plan.caution!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '注意: ${plan.caution}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// プラン情報の短いチップ表示。
class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF374151),
          fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// トレーニング種目の1行表示タイル。
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
  final int? calories;

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

