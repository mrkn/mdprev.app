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
