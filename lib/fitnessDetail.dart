import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'models/training_menu.dart';
import 'training_timer.dart';
import 'services/favorites.dart';
import 'services/media_service.dart';

class FitnessDetailPage extends StatefulWidget {
  const FitnessDetailPage({super.key, this.plan, this.exercise});

  final TrainingMenu? plan;
  final ExerciseItem? exercise;

  @override
  State<FitnessDetailPage> createState() => _FitnessDetailPageState();
}

class _FitnessDetailPageState extends State<FitnessDetailPage> {
  bool _isFav = false;
  ExerciseItem? get _targetExercise =>
      widget.exercise ??
      (widget.plan?.exercises.isNotEmpty == true
          ? widget.plan!.exercises.first
          : null);
  Uint8List? _headerImage;
  bool _loadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadFav();
    final ex = _targetExercise;
    final key = const String.fromEnvironment('OPENAI_API_KEY');
    if (ex != null) {
      setState(() {
        _loadingImage = true;
      });
      MediaService(apiKey: key)
          .getExerciseImageDetailed(ex.name, view: 'side', size: 512)
          .then((result) {
        if (!mounted) return;
        setState(() {
          _loadingImage = false;
          if (result.bytes != null && result.bytes!.isNotEmpty) {
            _headerImage = result.bytes;
          }
        });
      });
    }
  }

  Future<void> _loadFav() async {
    final ex = _targetExercise;
    if (ex == null) return;
    final fav = await FavoritesRepository().isFavorite(ex);
    if (!mounted) return;
    setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    final ex = _targetExercise;
    if (ex == null) return;
    final now = await FavoritesRepository().toggle(ex);
    if (!mounted) return;
    setState(() => _isFav = now);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(now ? 'お気に入りに追加しました' : 'お気に入りを解除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final exercise = widget.exercise;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                title: exercise?.name ?? plan?.name ?? 'プッシュアップ',
                subtitle:
                    exercise?.notes ?? plan?.summary ?? '胸筋・三頭筋・肩を鍛える基本トレーニング',
                onBack: () => Navigator.of(context).maybePop(),
                onFavorite: _toggleFav,
                isFavorite: _isFav,
                backgroundImage: _headerImage,
                loading: _loadingImage,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const _SectionTitle('トレーニング概要'),
                    const SizedBox(height: 12),
                    if (exercise != null)
                      _ExerciseInfoCard(item: exercise)
                    else if (plan != null)
                      _PlanInfoCard(plan: plan)
                    else
                      _InfoCard(cs: cs),
                    const SizedBox(height: 20),
                    if (exercise != null) ...[
                      const _SectionTitle('やり方'),
                      const SizedBox(height: 12),
                      _HowToFromExercise(item: exercise),
                      const SizedBox(height: 20),
                      const _SectionTitle('重要なコツ'),
                      const SizedBox(height: 12),
                      _TipsFromExercise(item: exercise),
                    ] else if (plan != null) ...[
                      const _SectionTitle('種目一覧'),
                      const SizedBox(height: 12),
                      _ExerciseList(plan: plan),
                      const SizedBox(height: 20),
                      const _SectionTitle('重要なコツ'),
                      const SizedBox(height: 12),
                      const _TipsCard(),
                    ] else ...[
                      const _SectionTitle('やり方'),
                      const SizedBox(height: 12),
                      const _HowToCard(),
                      const SizedBox(height: 20),
                      const _SectionTitle('重要なコツ'),
                      const SizedBox(height: 12),
                      const _TipsCard(),
                    ],
                    const SizedBox(height: 20),
                    const _SectionTitle('レベル別バリエーション'),
                    const SizedBox(height: 12),
                    const _VariationsList(),
                    const SizedBox(height: 24),
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () {
              final ex = _targetExercise;
              if (ex != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TrainingTimerPage(item: ex)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('開始できる種目がありません')));
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('トレーニングを開始'),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onFavorite,
    required this.isFavorite,
    this.backgroundImage,
    this.loading = false,
  });
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final bool isFavorite;
  final Uint8List? backgroundImage;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: backgroundImage == null
                    ? const LinearGradient(
                        colors: [Color(0xFF2D2F33), Color(0xFF0F1115)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                image: backgroundImage != null
                    ? DecorationImage(
                        image: MemoryImage(backgroundImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleIconButton(Icons.arrow_back, onBack),
                  _circleIconButton(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      onFavorite),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loading && backgroundImage == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'フォーム画像生成中…',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: const Color(0xFF111827)),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.cs});
  final ColorScheme cs;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: const [
          _InfoRow(icon: Icons.fitness_center, label: '難易度: 初級'),
          Divider(height: 1),
          _InfoRow(icon: Icons.timer, label: '時間: 10-15分'),
          Divider(height: 1),
          _InfoRow(icon: Icons.bolt, label: '効果: 胸筋、三頭筋、体幹'),
        ],
      ),
    );
  }
}

class _ExerciseInfoCard extends StatelessWidget {
  const _ExerciseInfoCard({required this.item});
  final ExerciseItem item;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          _InfoRow(icon: Icons.repeat, label: 'セット: ${item.sets ?? '-'}'),
          const Divider(height: 1),
          _InfoRow(
              icon: Icons.timer, label: '回数/秒数: ${item.repsOrSeconds ?? '-'}'),
          const Divider(height: 1),
          _InfoRow(icon: Icons.bedtime_off, label: '休憩: ${item.rest ?? '-'}'),
          if ((item.notes ?? '').isNotEmpty) ...[
            const Divider(height: 1),
            _InfoRow(
                icon: Icons.sticky_note_2_outlined, label: 'メモ: ${item.notes}')
          ],
        ],
      ),
    );
  }
}

class _PlanInfoCard extends StatelessWidget {
  const _PlanInfoCard({required this.plan});
  final TrainingMenu plan;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          _InfoRow(
              icon: Icons.event, label: '期間: ${plan.durationWeeks ?? '-'}週'),
          const Divider(height: 1),
          _InfoRow(
              icon: Icons.calendar_today,
              label: '頻度: ${plan.daysPerWeek ?? '-'}日/週'),
          const Divider(height: 1),
          _InfoRow(icon: Icons.speed, label: '強度: ${plan.intensity ?? '-'}'),
          if ((plan.caution ?? '').isNotEmpty) ...[
            const Divider(height: 1),
            _InfoRow(
                icon: Icons.warning_amber_rounded, label: '注意: ${plan.caution}')
          ],
        ],
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.plan});
  final TrainingMenu plan;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < plan.exercises.length; i++) ...[
            _ExerciseRow(item: plan.exercises[i]),
            if (i != plan.exercises.length - 1) const Divider(height: 1),
          ]
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.item});
  final ExerciseItem item;
  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(fontSize: 13, color: Color(0xFF374151));
    return ListTile(
      dense: true,
      title: Text(item.name,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827))),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            if (item.sets != null) Text('セット: ${item.sets}', style: style),
            if ((item.repsOrSeconds ?? '').isNotEmpty)
              Text('回数/秒数: ${item.repsOrSeconds}', style: style),
            if ((item.rest ?? '').isNotEmpty)
              Text('休憩: ${item.rest}', style: style),
            if ((item.notes ?? '').isNotEmpty)
              Text('メモ: ${item.notes}', style: style),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF6B7280)),
      ),
      title: Text(
        label,
        style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: const [
          _StepItem(
            number: 1,
            title: 'スタートポジション',
            body: '両手を肩幅より少し広めに床につき、つま先で体を支えます。頭からかかとまで一直線になるようにします。',
          ),
          Divider(height: 1),
          _StepItem(
            number: 2,
            title: '下降動作',
            body: '肘を曲げながら胸が床につく直前まで体を下げます。この時、体は一直線を保ちます。',
          ),
          Divider(height: 1),
          _StepItem(
            number: 3,
            title: '上昇動作',
            body: '胸筋を使って体を押し上げ、スタートポジションに戻ります。肘は完全に伸ばしきらず。',
          ),
        ],
      ),
    );
  }
}

class _HowToFromExercise extends StatelessWidget {
  const _HowToFromExercise({required this.item});
  final ExerciseItem item;
  @override
  Widget build(BuildContext context) {
    final steps = item.steps.isNotEmpty
        ? item.steps
        : [
            '正しいフォームで開始姿勢を作る',
            '反動を使わず、ゆっくりとコントロールして動く',
            '呼吸を止めずに繰り返す',
          ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepItem(number: i + 1, title: 'ステップ ${i + 1}', body: steps[i]),
            if (i != steps.length - 1) const Divider(height: 1),
          ]
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem(
      {required this.number, required this.title, required this.body});
  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text('$number',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151), height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: const [
          _TipRow(text: '体を一直線に保つ・お尻が上がったり下がったりしないよう注意'),
          _TipRow(text: '呼吸を意識する・下げる時に息を吸い、上げる時に息を吐く'),
          _TipRow(text: '手の位置・肩の真下より少し外側に置く'),
          _TipRow(text: 'ゆっくりとした動作・2秒で下げ、1秒で上げるペースを意識'),
        ],
      ),
    );
  }
}

class _TipsFromExercise extends StatelessWidget {
  const _TipsFromExercise({required this.item});
  final ExerciseItem item;
  @override
  Widget build(BuildContext context) {
    final tips = item.tips.isNotEmpty
        ? item.tips
        : [
            '反動を使わず可動域をコントロールする',
            '痛みが出る手前で可動域を調整する',
            '呼吸は止めず、動作に合わせて行う',
          ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final t in tips) _TipRow(text: t),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1F2937), height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariationsList extends StatelessWidget {
  const _VariationsList();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _VariationCard(
          pillText: '初級',
          pillColor: Color(0xFFE6FFFA),
          title: '膝つきプッシュアップ',
          body: '膝を床につけて行うことで負荷を軽減できます。',
        ),
        SizedBox(height: 10),
        _VariationCard(
          pillText: '中級',
          pillColor: Color(0xFFFFF7E6),
          title: '標準プッシュアップ',
          body: 'つま先で体を支える基本的なフォームです。',
        ),
        SizedBox(height: 10),
        _VariationCard(
          pillText: '上級',
          pillColor: Color(0xFFFFE6E9),
          title: '片手プッシュアップ',
          body: '片手で行う高難度バリエーション。体幹の強化にも効果的です。',
        ),
      ],
    );
  }
}

class _VariationCard extends StatelessWidget {
  const _VariationCard({
    required this.pillText,
    required this.pillColor,
    required this.title,
    required this.body,
  });
  final String pillText;
  final Color pillColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pillText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF111827)),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF4B5563), height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
