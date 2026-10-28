# v0.32 正式ソースの受け取りと再検証

2026-10-29、ユーザー提供の ice_forest_v032.zip を取得。
SHA256: 24ce3db73532177b166a7c20024eb57a81d20d41fefb588c3e78c0bfe8fcb008

ZIP内の ice_forest_proto を、このブランチの game/ に配置した。以前のPR #3の雪の森・青い欠片・追跡者の試作を改修元にしていない。ZIP内の説明文が主張する検証と、今回の再実行結果を区別する。

## 今回再確認したこと

Godot 4.7.2.stable.official.ed1daf0bf、Windows、RTX 5060。

- Compatibilityの verify.gd：点灯時のみ調査、棒の固定、字幕への転記なし、Escで復帰、最奥到達後の帰還、棒0本でのクリア、再生成を確認。
- Compatibilityの verify_camera.gd：距離同期の歩行・早歩き、停止時の呼吸、揺れOFFの視点復帰を確認。
- Compatibilityの verify_environment.gd：杭・轍・パイプの描画と、遮蔽物による寄り拒否を確認。
- Forward+の verify_night.gd / verify_visual.gd：消灯・点灯の描画、露出固定、375本の杉の形状と当たり判定、看板、ライト設定を確認。
- verify_audio.gd：固定シード1000回中104回の遅延足音予約、遅延再生・停止後の1歩・環境音のフェード・再生成を確認。

最初に描画なしで verify.gd と verify_camera.gd を実行した際は、マウス捕捉に依存するカメラ更新が進まずassertで停止した。この2本をheadless成功として扱っていない。実際の描画環境ではいずれも成功。CIでも仮想画面で描画して検証する。

## この取り込みで加えたもの

ゲーム処理・会話・棒の文字・配置・シェーダーを変更せず、Windows export preset、.gitignore、CIを追加。ソース起動用cmdの個人PC固定パスはGODOT_EXE環境変数または同梱Godot.exe参照へ変更。元ZIPは変更しない。

手動通しプレイ、初見テスト、音の聴感評価、最終性能評価、Steam対応は未実施。取得済みソースを基準に今後の修正箇所を選び、既に実装済みのv0.32機能を作り直さない。
