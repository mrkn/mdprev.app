# TODO

## 目的
`mdprev` の実装品質を上げるため、既知の改善項目と仕様確定事項を TODO 化する。

## 優先タスク
- [ ] `NSEvent` ローカルモニタのライフサイクルを修正する
  - 現状:
    - ウィンドウクローズ時の `removeMonitor` は実装済み。
    - ただし `IMKCFRunLoopWakeUpReliable` のログは再現し、入力処理まわりの課題が残っている。
  - 対応:
    - `Cmd+A` / `Cmd` / `Option` 入力時に IMK ログが出ないようにする。
    - 複数ウィンドウの開閉を繰り返してもモニタが増殖しないことを確認する。
  - 進捗:
    - `KeyboardShortcutService` は `keyDown` の `Cmd+A` のみを監視し、`flagsChanged` 監視を廃止。
    - 手動確認手順を `docs/manual_test_procedures.md` に追加（実機確認待ち）。

- [x] `RecentFilesStore` の読み込み時にも最大件数 (`10`) を強制する
  - 対応済み:
    - ロード時点で最大件数に切り詰める。
    - 重複排除・順序維持の既存仕様を維持。

- [x] Markdown 内ローカルリンクのファイルタイプごとの挙動を制御する
  - 仕様:
    - `.md` / `.markdown` のみ「新規ウィンドウで開く」対象とする。
    - それ以外は仮実装として、そのファイルがあるフォルダを Finder で開く。
  - 対応済み:
    - `LocalFileLinkResolver` を導入し、拡張子と存在有無で分岐させる。
  - TODO（継続）:
    - 非 Markdown ファイルをどう扱うべきかの本実装方針を後で決める。

- [x] `mdprev-open-file://` の扱いを制限する
  - 対応済み:
    - 上記ファイルタイプ制御を適用する。
    - `file://` と同等にローカルリンク扱いし、想定外の入力は外部 URL フローへ回す。

- [x] `Option + クリック`（Open Recent）の挙動を一意にする
  - 確定仕様:
    - `Option + クリック` は「新規ウィンドウを作って、選択したファイルを開く」。
    - 既存ウィンドウの有無に依存させない。
  - 対応済み:
    - フォーカスウィンドウがある場合でも、現在ウィンドウを上書きせず新規ウィンドウで開く。
    - フォーカスウィンドウがない場合も同じ挙動にする。

## 実装品質レビュー TODO（2026-03-05）
- [x] P1: `Open Recent` の `Option + クリック` 挙動を仕様どおりに修正する
  - 対応済み:
    - `RecentFileOpenAction` を導入し、`Option + クリック` は常に「選択ファイルを新規ウィンドウで開く」へ統一。

- [x] P2: Finder 連携 (`application:openFile/openFiles`) の配送先を決定的にする
  - 対応済み:
    - 優先消費ウィンドウを `key` → `main` → 最小 `windowNumber` の順で決定。
    - `AppOpenFileQueue` は優先ウィンドウが一括消費し、複数ファイルは先頭を現在ウィンドウ、残りを新規ウィンドウで開く。

- [x] P2: `HighlightJSThemeCatalog` の CSS 読み込みを遅延化する
  - 対応済み:
    - 初期化時はテーマ定義（identifier/displayName/fileURL）のみ収集する。
    - CSS 本体はテーマ選択時にオンデマンドで読み込み、メモリ内キャッシュで再利用する。

- [x] P3: `MDPrevCommands` のテーマメニュー構築ロジックを整理する
  - 対応済み:
    - `SyntaxHighlightThemeMenuModel` を導入し、正規化・ソート・グルーピングを専用型へ分離。
    - `MDPrevCommands` 側はメニュー描画に専念させ、重複していた処理を削減した。

- [x] P3: `AppModel` の責務を分割する
  - 対応済み:
    - `FileOpenService` / `ExternalURLService` / `KeyboardShortcutService` を導入。
    - `AppModel` からファイル選択/読込、外部 URL 確認、キーボード監視を分離し、依存注入可能にした。

- [x] P3: `MarkdownRenderer` の code fence 情報解析を分離する
  - 対応済み:
    - `CodeFenceMetadataParser` を独立型として抽出し、`MarkdownRenderer` から解析責務を分離。
    - parser 専用ユニットテストを追加し、代表的な info string バリエーションを直接検証できるようにした。

## テスト TODO
- [x] キーボードモニタ解除の回帰テスト戦略を追加する（少なくとも手動再現手順を `README` か `docs` に記載）。
  - 対応済み:
    - `docs/manual_test_procedures.md` に IMK ログ再現防止とウィンドウ増減時の確認手順を記載。
- [x] Recent Files の「ロード時 10 件制限」をテストで保証する。
- [x] `Option + クリック` の分岐ロジックをユニットテストで保証する。
- [x] Finder 連携の優先消費ウィンドウ選択ロジックをユニットテストで保証する。
- [x] `Option + クリック` の挙動を仕様どおりに確認する UI テストまたは手動テスト手順を追加する。
  - 対応済み:
    - `docs/manual_test_procedures.md` に `Open Recent: Option + Click` の確認手順を追加。
- [ ] 非 Markdown のローカルリンク選択時に Finder が開くフォールバックの手動検証手順を追加する。
- [ ] 外部 URL リンクの「確認ダイアログ + HEAD リダイレクト警告」の手動検証手順を追加する。
