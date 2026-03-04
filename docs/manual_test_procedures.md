# Manual Test Procedures

## Keyboard Monitor Regression (`IMKCFRunLoopWakeUpReliable`)

### 目的
- `Cmd` / `Option` / `Cmd+A` 入力で `IMKCFRunLoopWakeUpReliable` ログが出ないことを確認する。
- ウィンドウの増減を繰り返しても、キーボードショートカットの挙動が劣化しないことを確認する。

### 前提
- リポジトリルートで `swift run` を実行してアプリを起動する。
- `swift run` の標準出力を見える状態にする。

### 手順
1. 起動直後の最初のウィンドウをアクティブにする。
2. `Command` キーを単体で押して離す。次に `Option` キーを単体で押して離す。
3. `Command + A` を押して全選択する。
4. 2-3 を 10 回程度繰り返す。
5. `File > New Window` などでウィンドウを 3 枚以上に増やす。
6. 1 枚ずつ閉じる操作と新規作成を 5 サイクル程度繰り返す。
7. 各サイクルで 2-4 を実施する。

### 期待結果
- `swift run` 出力に `IMKCFRunLoopWakeUpReliable` が出ない。
- `Command + A` で Markdown 本文全体が選択される。
- ウィンドウ増減後も `Command + A` の挙動が変化しない。

## Open Recent: Option + Click

### 目的
- `Open Recent` の `Option + クリック` が、常に新規ウィンドウでファイルを開くことを確認する。

### 前提
- `Open Recent` に少なくとも 2 件の Markdown ファイルが登録されている。

### 手順
1. `Open Markdown...` で `A.md` を開く。
2. `Open Markdown...` で `B.md` を開く（Recent を更新する）。
3. `A.md` を表示したウィンドウをアクティブにする。
4. `File > Open Recent` を開き、`Option` を押しながら `B.md` をクリックする。

### 期待結果
- `A.md` を表示していた元ウィンドウはそのまま残る。
- 新しいウィンドウが作成され、そのウィンドウで `B.md` が開く。

## Local Link Fallback: Non-Markdown File

### 目的
- Markdown 内の非 Markdown ローカルリンクをクリックしたとき、対象ファイルそのものではなく親フォルダが Finder で開くことを確認する。

### 前提
- テスト用フォルダに以下を用意する:
  - `index.md`
  - `assets/spec.pdf`（任意の非 Markdown ファイル）
- `index.md` に `[spec](./assets/spec.pdf)` のリンクを記述する。

### 手順
1. `index.md` を mdprev で開く。
2. 本文中の `spec` リンクをクリックする。

### 期待結果
- `assets/spec.pdf` の親フォルダ（`assets/`）が Finder で開く。
- mdprev 側はクラッシュせず、ステータスバーにフォルダを開いた旨が表示される。
