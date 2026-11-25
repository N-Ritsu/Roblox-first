# Roblox-first

Claude が毎週自動で開発・公開する Roblox ゲーム。

- 方針の指示：`DIRECTION.md` を編集
- 開発の記録：`DEVLOG.md`、タスク一覧：`BACKLOG.md`
- 自動公開：`main` への push で GitHub Actions が Rojo でビルドして公開

## 必要な設定（Settings → Secrets and variables → Actions）
- Secret `ROBLOX_API_KEY`：Roblox Open Cloud の APIキー（universe-places の Write 権限）
- Variable `ROBLOX_UNIVERSE_ID`：ゲームの Universe ID
- Variable `ROBLOX_PLACE_ID`：場所の Place ID

## Roblox 側でおすすめの設定
- サーバーの最大人数：**6人**（店舗区画が6つのため。7人目はお店を持てない）
- Game Settings → Security → **Enable Studio Access to API Services** を ON（Studio でもセーブを試せる）

## ゲームの遊び方（マイショップ・クラフト）
1. 自分のお店（区画）に入る。左の「工房」で部品（形・色・素材・大きさ・位置・向き）を組み合わせてアイテムをデザインし、保存する
2. 「1個」「5個」でコインを払って在庫を作る
3. 店の陳列台に近づいて商品と値段を決めて並べる
4. お客さんNPCが来て、値段が「払ってもいい額」以下なら買う → コイン。好み・今週のお題・お金持ちのお客さんで高く売れることも
5. コインで「部品」（新しい形・色・素材、部品の数の上限）や「お店」（店頭の陳列台・壁と床・キャッチコピー）を拡張
6. 店の「自宅」ドアから自分の部屋へ。作ったアイテムをマス目に飾れる。他の人の自宅を訪問していいねもできる
7. 「めぐる」で他の人の店へ行って買い物（買ったものは自宅に飾れる）
8. 毎日のログインボーナス、留守中の売上、「目標」の報酬、店の評判（★）、冬の季節イベント（12/1〜1/7）

## コードの構成（src）
### server（ServerScriptService）
| ファイル | 役割 |
|---|---|
| Main.server.luau | 各サービスを順に起動 |
| DataService | セーブデータ（DataStore、UpdateAsync＋簡易セッションロック、pcall で保護） |
| WorldService | ライティング・中央広場 |
| PlotService | 店舗区画（建物・陳列台・工房・自宅の部屋）の生成と割り当て |
| DesignService | デザインの保存・削除（名前は TextService でフィルター） |
| ShopService | 製作・陳列・購入・店の拡張・評判・留守中の売上・キャッチコピー |
| CustomerService | お客さんNPC（来店・好み・お題・お金持ち） |
| UnlockService | 部品の解放・部品の数の拡張 |
| DailyService | ログインボーナス・初回ガイドの完了 |
| HomeService | 自宅の行き来・飾る・公開・いいね |
| RankingService | 広場のランキング掲示板 |
| GoalService | 目標の報酬 |
| SeasonService | 季節イベントの飾り |
| TravelService | お店めぐりのワープ |

### client（StarterPlayerScripts）
Hud（コイン・お題・通知）、Workshop（工房）、ShelfPanel（陳列台）、PartShop（部品）、ShopPanel（お店）、GoalsPanel（目標）、TravelPanel（めぐる）、HomePanel（模様替え）、Guide（初回ガイド・ボーナス表示）、Prompts（自分の店か他人の店かでプロンプトを切り替え）、UI・Sounds・State（共通部品）

### shared（ReplicatedStorage）
Config（設定値・バージョン）、Catalog（部品一覧）、ItemBuilder（デザインの検証・価値・3D化）、ShopUpgrades（店の拡張一覧）、Goals（目標一覧）、Theme（今週のお題）、Season（季節イベントの期間）、Net（リモート通信）

## 課金を入れるとき（DIRECTION.md で指示があったら）
課金はまだ入れていません。入れるときは次の「解放する処理」に Developer Products / ゲームパスの購入処理をつなぐ想定です。
- 部品の解放：`UnlockService`（`unlock` / `buyPartLimit`）
- 店の拡張：`ShopService`（`buyShelfSlot` / `setInterior`）、一覧は `shared/ShopUpgrades.luau`
- ワールド内通貨：`DataService.AddCoins`
