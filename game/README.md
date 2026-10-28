# ICE FOREST — Windows prototype 0.1

最終目標はSteamなどから配布できるWindows用exeです。このフォルダーはGodot 4.7.2（標準版・GDScript）で動く最初の技術試作です。Steam SDK、ストア登録、課金、オンライン通信はありません。

## 仮の遊び

雪の森を一人称で歩き、青い欠片を3つ拾って、正面奥の暖色の門から脱出します。最初の欠片を拾うと影が追跡を始めます。捕まると再挑戦できます。この探索目標、追跡者、雪景色、演出は試作用の仮仕様であり、完成版の物語・ゲームデザインの承認を意味しません。

- WASD / 矢印：移動
- マウス：視点
- Shift：走る（スタミナ消費）
- E：近くの欠片を拾う／門から出る
- F：ライトのON/OFF
- Esc：一時停止・マウス解放

タイトル画面の「森に入る」で開始。「終了」で閉じます。自動セーブ、ゲームパッド、キー変更、正式な音量設定、アクセシビリティ調整、Steam実績、インストーラーは未実装です。

## 開発と検証

Godotで project.godot を開いてF6/F5で起動できます。依存アドオンは不要です。森・UI・音はコードで生成します。

Godotのコマンドラインで次を実行します。

```
godot --headless --path game --editor --import --quit
godot --headless --path game --script res://tests/test_run_state.gd
godot --headless --path game --script res://tests/test_scene.gd
godot --headless --path game -- --smoke
```

状態処理はJules（Gemini）が実装し、GPT側がテスト終了コードを補強して3D環境・操作・UIへ統合しました。状態34項目とシーン統合13項目を確認します。統合テストは移動、一時停止、取得条件、脱出、捕獲、再開を含みます。自動テストは人による面白さ・快適さの評価の代わりではありません。

## Windowsへの書き出し

Godot 4.7.2に同じ版のWindows x86_64 release export templateを設定し、Windows Desktopプリセットでexportします。コード署名は未設定です。出力された `IceForest.exe` と `IceForest.pck` を同じフォルダーに置いて配布します。`GODOT_LICENSE.txt` を同梱してください。現時点ではSteam公開用の完成品ではありません。

GitHub CIは公開リポジトリの標準ランナーでテストだけを行います。課金につながるartifact/cache保管や自動配布は設定しません。
