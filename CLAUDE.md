# このリポジトリでの作業ルール（自動実行用）

このリポジトリは、Claude が毎週の余った使用量で Roblox ゲームを自動開発・公開するためのものです。
オーナーは大まかな方向性だけを DIRECTION.md で指示します。

## 構成
- `src/server` → ServerScriptService、`src/client` → StarterPlayerScripts、`src/shared` → ReplicatedStorage（Rojo / `default.project.json`）
- 言語は Luau。`.server.luau` / `.client.luau` / モジュールは `.luau`
- `main` に push されると GitHub Actions が Rojo でビルドし、Roblox に自動公開する
- 開発は `dev` ブランチで行う。`main` へのマージは「公開回」だけ

## 毎週のスケジュール（日本時間）
1. 水曜 20:00 頃「企画・実装回」：DIRECTION.md と DEVLOG.md を読み、今週の目標を決めて実装を始める
2. 木曜 1:00 頃「実装回」：前回の続きを実装する
3. 木曜 6:20 頃「仕上げ・公開回」：見直しと修正をして、問題がなければ `dev` を `main` にマージして公開する

## 毎回の手順
1. `git fetch` して `dev` をチェックアウト（なければ `main` から作る）。`main` の変更は `dev` に取り込む
2. DIRECTION.md（オーナーの指示、最優先）と DEVLOG.md（前回までの記録）を読む
3. 作業する。1回で終わらなくてよい。区切りのよいところでこまめにコミット・push する
4. 最後に DEVLOG.md の先頭に「日付・回の種類・やったこと・次回やること」を追記して push する

## 開発方針
- 毎週ゼロから作り直さず、1本のゲームを育てる。継続率（また遊びに来たくなるか）を最重視する
- 3Dモデルや画像は作れないので、パーツ・ライティング・エフェクト・UI で見た目を工夫する
- 1回の変更は小さく保ち、公開回までに動く状態に戻す。自信のない変更は `main` にマージしない
- DataStore を使う場合は pcall で包み、失敗してもゲームが止まらないようにする
- 収益化（ゲームパス・Developer Products）は DIRECTION.md で指示があるまで導入しない。導入する場合も公開回より前にオーナーへ確認する
- Roblox のコミュニティ規約に反する内容（過度な暴力、ギャンブル的な有料ガチャ等）は作らない

## やってはいけないこと
- `.github/workflows` と DIRECTION.md の書き換え（オーナー管理）
- APIキーなどの秘密情報をファイルに書くこと
- `main` への force push、履歴の書き換え
