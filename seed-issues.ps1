Param(
  [string]$Repo = "GotoShinnnosuke/2025procon"
)

Write-Host "Target repo: $Repo" -ForegroundColor Cyan

# 推奨ラベルを作成（存在していればスキップ）
$labels = @(
  @{ name="type:feat";       color="#1f883d" },
  @{ name="type:chore";      color="#bf8700" },
  @{ name="type:bug";        color="#d73a4a" },
  @{ name="area:ui";         color="#0e8a16" },
  @{ name="area:state";      color="#5319e7" },
  @{ name="area:data";       color="#0052cc" },
  @{ name="area:api";        color="#0366d6" },
  @{ name="priority:high";   color="#d93f0b" }
)
foreach ($l in $labels) {
  gh label create $l.name -R $Repo -c $l.color 2>$null
}

# Issue 定義
$issues = @(
  @{
    title = "chore: Flutter プロジェクト初期化";
    body = @'
M0 初期化
- `flutter create`
- ディレクトリ雛形: `lib/ui`, `lib/state`, `lib/data`, `lib/common`

**受け入れ基準**
- Android / iOS / Web でビルド通過
'@;
    labels = @("type:chore","priority:high")
  },
  @{
    title = "chore: CI（analyze/test）導入";
    body = @'
GitHub Actions で `flutter analyze` / `flutter test` を実行。

**受け入れ基準**
- PRでCIが動き、成功しないとマージ不可
'@;
    labels = @("type:chore")
  },
  @{
    title = "chore: ルーティング/テーマ基盤";
    body = @'
GoRouter（または標準ルーティング）、ライト/ダークテーマ、共通コンポーネントの土台を用意。

**受け入れ基準**
- 主要画面への仮遷移が動く
'@;
    labels = @("type:chore","area:ui")
  },
  @{
    title = "feat: 認証UI（ログイン/サインアップ）";
    body = @'
メール+パスの入力フォーム。基本バリデーション。

**受け入れ基準**
- 成功/失敗のUI状態が反映される
'@;
    labels = @("type:feat","area:ui","priority:high")
  },
  @{
    title = "feat: 認証State（Controller/Provider）";
    body = @'
AuthRepository（モック）と連携して SignUp / SignIn / SignOut を制御。

**受け入れ基準**
- UI操作に応じて状態遷移する
'@;
    labels = @("type:feat","area:state")
  },
  @{
    title = "feat: 認証データ層（モック実装）";
    body = @'
後で Firebase 等に差し替え可能なインターフェースでモックを実装。

**受け入れ基準**
- Repository 経由で認証が通る
'@;
    labels = @("type:feat","area:data")
  },
  @{
    title = "feat: ホーム入力UI（部位/やってみたい種目）";
    body = @'
部位（腹/脚/背中/腕/お尻/全身…複数選択）＋自由入力1つ。

**受け入れ基準**
- 入力→提案アクション起動
'@;
    labels = @("type:feat","area:ui","priority:high")
  },
  @{
    title = "feat: 提案アルゴ v0（ルールベース）";
    body = @'
入力内容からプリセット辞書で候補 3〜6 件を返す（AI API は後続）。

**受け入れ基準**
- 入力条件に応じて候補が変わる
'@;
    labels = @("type:feat","area:state")
  },
  @{
    title = "feat: 候補一覧UI（カードリスト）";
    body = @'
時間 / 消費カロリー目安 / 対象部位タグ。タップで詳細へ。

**受け入れ基準**
- タップで詳細画面に遷移
'@;
    labels = @("type:feat","area:ui")
  },
  @{
    title = "feat: トレーニング詳細画面";
    body = @'
手順 / 注意 / 必要器具 / 目安時間 / 実行ボタン。

**受け入れ基準**
- 「実行」押下でセッション開始
'@;
    labels = @("type:feat","area:ui","priority:high")
  },
  @{
    title = "feat: 実行/タイマー&進捗（v0）";
    body = @'
スタート / 一時停止 / 完了、経過時間、セット / 回数。

**受け入れ基準**
- 完了時に実施結果オブジェクトを返す
'@;
    labels = @("type:feat","area:state")
  },
  @{
    title = "feat: データモデル設計（User/Training/TrainingSession）";
    body = @'
`TrainingSession { date, duration, sets, reps, tags }` を含むデータモデル設計。

**受け入れ基準**
- 型 / 変換 / 最小テストがある
'@;
    labels = @("type:feat","area:data")
  },
  @{
    title = "feat: ローカルDB導入（Hive/Isar）";
    body = @'
セッション保存 / 取得 API を実装。

**受け入れ基準**
- 再起動後も履歴が保持される
'@;
    labels = @("type:feat","area:data","priority:high")
  },
  @{
    title = "feat: 完了→保存 連携";
    body = @'
実行完了時に TrainingSession を永続化。

**受け入れ基準**
- 完了直後に DB へ保存
'@;
    labels = @("type:feat","area:state","area:data")
  },
  @{
    title = "feat: カレンダーUI（月/日）";
    body = @'
実施日をドット表示、タップで日別一覧。

**受け入れ基準**
- 対象日タップで当日のセッション一覧へ
'@;
    labels = @("type:feat","area:ui")
  },
  @{
    title = "feat: 履歴一覧/詳細（フィルタ/ソート）";
    body = @'
期間 / 部位 / 種目で絞り込み表示。

**受け入れ基準**
- 条件に応じて表示が更新される
'@;
    labels = @("type:feat","area:ui")
  },
  @{
    title = "feat: AI候補生成 v1（API接続・フォールバック）";
    body = @'
ルールベースと切替可能に。API 不通時はルールベースへフォールバック。

**受け入れ基準**
- 切替スイッチ / 失敗時フォールバックを実装
'@;
    labels = @("type:feat","area:api")
  },
  @{
    title = "chore: 例外処理/ローディング/再試行UX";
    body = @'
Snackbar / Retry / 空状態プレースホルダを各画面に整備。

**受け入れ基準**
- 主要経路で例外時に落ちない
'@;
    labels = @("type:chore","area:ui")
  }
)

# Issue 一括作成
$created = 0
foreach ($it in $issues) {
  $args = @("--title", $it.title, "--body", $it.body)
  foreach ($lb in $it.labels) { $args += @("--label", $lb) }
  gh issue create -R $Repo @args
  $created++
}
Write-Host "Done. Created $created issues and ensured labels." -ForegroundColor Green
