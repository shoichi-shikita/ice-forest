# アイスの森：追加料金0円の開発連携・初期実装

状態：公開リポジトリへ配置済み。Actionsの9件のテスト、Jules APIの認証・対象ソース確認、テストPR #1へのCodex自動レビュー完了を確認済み。Julesの文書作成→PR #3作成→Codex自動レビュー完了も確認済みです。ゲーム本体・確定したゲーム仕様はまだ含まれません。

## 実装した流れ

GitHubのIssueを指定してActionsを実行 → Julesに1件だけ依頼 → Julesで計画承認 → クラウドで実装 → PR自動作成 → 接続済みCodexの自動レビュー。Codexの接続・自動レビューはPR #1で確認済みです。

AI間の回答コピペは不要です。初回認証、タスク指示、Jules計画承認、最終マージは人が行います。PCを切っていても、開始済みのGitHub/Jules/Codexクラウド処理はローカルPCに依存しません。これは設計上の性質であり、文書1件での実アカウント通し検証結果はIssue #2とPR #3に記録済みです。

## 承認後の導入

1. 所有者とリポジトリ名、公開可否を決定します。ゲーム資料や未公開シナリオを公開してよいとは仮定しません。
2. 公開を承認された場合、このフォルダーの内容を新規リポジトリに配置します。既存ファイルがある場合は上書きせず統合します。
3. Google AI Proと同じアカウントでJulesにログインし、GitHub Appにこのリポジトリだけのアクセスを許可します。Jules設定でAPIキーを作成し、GitHubのActions secret `JULES_API_KEY` に登録します。キーをチャットに貼らないでください。これらの認証・権限操作は別途本人承認後に行います。
4. Codexに同じリポジトリを接続し、Automatic reviewを有効にします。追加クレジット購入や自動購入は有効にしません。
5. GitHubのActions variable `AUTOMATION_ENABLED` を `true` にします。初期値は未設定＝停止です。
6. 実装してほしい内容と完了条件をIssueに記載します。リポジトリ所有者が `ai-ready` ラベルを付けると開始します。ラベルがなければGitHubのIssue画面で作成してください。Actionsの「Ice Forest task」からIssue番号を指定する方法も残しています。
7. Issueコメントのセッション番号をJulesで確認し、計画を承認します。JulesがPRを作成したら、Codex設定に従い自動レビューが走ることを確認します。
8. ゲーム本体の実装時に適切なテストを追加します。この同梱CIは連携コードのテストだけです。ゲームの品質や動作を保証しません。

## 実証済みの範囲

2026-10-29、固定した文書1件の依頼をActionsからJulesへ送信し、JulesがPR #3を作成、Codexが自動レビューを完了しました。レビューでは開始条件の記述に指摘があり、このチャットの担当エージェントが修正しました。後続のPR #4で、最大2回のレビュー返送と再レビュー依頼を実装・統合しました。対象PRへ `ai-auto-fix` を付けて利用します。19件のテストとCodex再レビューが成功し、クラウド上で指摘なしの場合の無送信を確認済みです。自動修正一巡の実証は未完了です。文書での成功はゲーム本体の完成や品質保証を意味しません。PRは未マージです。

## 通し検証の記録

- [Codex自動レビュー成功：PR #1](https://github.com/shoichi-shikita/ice-forest/pull/1)
- [Jules認証・対象確認成功](https://github.com/shoichi-shikita/ice-forest/actions/runs/40752415871)
- [Jules実作業の記録：Issue #2](https://github.com/shoichi-shikita/ice-forest/issues/2)

- [Jules作成PRとCodexレビュー：PR #3](https://github.com/shoichi-shikita/ice-forest/pull/3)
- [通し検証Actions：成功](https://github.com/shoichi-shikita/ice-forest/actions/runs/40758093940)

`Jules end-to-end verification` は固定の文書1件だけを自動計画承認で依頼します。通常のIssue依頼は計画承認が必要です。再実行は記録済みセッションの監視を再開し、新しいセッションを作りません。最大約12分の監視終了はJules自体の停止を意味しません。`Jules session status` はこのテストセッションを読むだけです。いずれも定期実行はありません。

## 停止・復旧

`AUTOMATION_ENABLED` を削除するか `false` にすると新規依頼を停止します。開始済みJulesセッションはJules側で停止してください。API失敗、無料枠上限、タイムアウトは自動再試行しません。作成開始コメントを記録してからJulesを呼び出し、同じIssueの再実行を抑止します。中断時はJulesを調べ、未作成と確認できた場合だけbotの開始コメントを削除して再実行します。コメント削除・編集や別経路からのAPI呼び出しまで含めた厳密な一度限り実行は保証しません。

## 0円の境界と制限

- OpenAI APIは呼びません。Plus内のCodex自動レビューを利用する設計で、利用枠終了時の継続や追加購入は行いません。契約全体で別途設定済みの購入設定まではこのコードでは管理できません。
- Gemini Developer APIも呼びません。無料枠はGoogle AI Proと別です。キーだけでは課金設定を確認できないため、課金アカウント未連携の専用プロジェクトを確認できるまでは導入対象から外しています。無料枠ではデータ利用条件にも注意が必要です。
- JulesはGoogle AI Proの既存枠を使う前提です。本人の契約適用・API可用性は認証後に確認が必要です。枠超過は停止し、プラン変更しません。
- Actionsは公開リポジトリの標準 `ubuntu-latest` のみ。非公開ではjob条件でランナー割当て前に停止します。artifact/cache、上位ランナー、外部ホスティングは使いません。非公開を公開に変更する処理はありません。
- GPTとGeminiの無制限な討議、無制限のレビュー返送、自動マージ、24時間の継続開発は実装していません。通常の実装依頼は1タスク・1セッションです。オプトインしたPRでは上限付きの修正返送を追加しています（[運用手順](docs/automatic-feedback.md)）。自動レビューが承認や合格を意味するとも扱いません。
- Julesの計画承認は必要です。コード変更はPRとしてレビューします。プロンプトの禁止事項はサービス側権限の代わりにはならないため、Appの権限は対象リポジトリに限定してください。
- 自動修正の確認は約30分間隔とCodexコメントイベントで行います。課金・認証設定の追加変更はありません。

## 検証

Node.js 22以上で `npm test`。外部リクエストを模擬し、停止設定、入力検証、非公開遮断、権限、ラベル、接続欠如、重複防止、計画承認、タイムアウト無再試行、エラー本文非表示を検証します。クラウドCI、Julesの認証・対象ソース確認、Codex自動レビューは実アカウントで確認済みです。Jules自身による文書PR作成とCodexレビューも確認済みです（PR #3）。ゲームコード、通常依頼の計画承認経路、ラベル起動経路の実動作、無人の相互再修正は未検証です。

## 公式根拠（確認日：2026-10-29）

- [OpenAI：PlusとCodexの利用範囲・制限](https://learn.chatgpt.com/docs/pricing)
- [OpenAI：GitHub自動レビュー設定](https://learn.chatgpt.com/docs/third-party/github)
- [Jules：API・認証・ソース接続・PR自動作成](https://jules.google/docs/api/reference)
- [Jules：セッションと計画承認](https://jules.google/docs/api/reference/sessions)
- [Jules：Google AI Proに含まれる利用枠](https://jules.google/docs/usage-limits)
- [Gemini API：無料枠と課金の区別](https://ai.google.dev/gemini-api/docs/billing)
- [GitHub Actions：公開標準ランナーと非公開の超過課金](https://docs.github.com/en/actions/concepts/billing-and-usage)

仕様や料金は変更され得ます。稼働開始前に再確認します。料金不明の場合は実行しません。
