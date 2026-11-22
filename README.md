# Roblox-first

Claude が毎週自動で開発・公開する Roblox ゲーム。

- 方針の指示：`DIRECTION.md` を編集
- 開発の記録：`DEVLOG.md`
- 自動公開：`main` への push で GitHub Actions が Rojo でビルドして公開

## 必要な設定（Settings → Secrets and variables → Actions）
- Secret `ROBLOX_API_KEY`：Roblox Open Cloud の APIキー（universe-places の Write 権限）
- Variable `ROBLOX_UNIVERSE_ID`：ゲームの Universe ID
- Variable `ROBLOX_PLACE_ID`：場所の Place ID
