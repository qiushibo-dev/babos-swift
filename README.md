# Babos (Swift)

[Babos](https://github.com/qiushibo-dev/work-log) の SwiftUI 版。個人用の作業記録アプリ。

**一つの案件が一つの気泡。** 大きさは「その案件が今どれだけ頭を占めているか」、
濃さは「どこまで進んだか」。二つは独立していて、同じ方向には動かない。

macOS 専用（Apple Silicon）。

---

## 二つの版の関係

| | [HTML / Tauri 版](https://github.com/qiushibo-dev/work-log) | この Swift 版 |
|---|---|---|
| 位置づけ | **試験場** | **本命** |
| 対応 | macOS ＋ Windows | macOS のみ |
| 中身 | 単一 HTML を Tauri で包む | SwiftUI ネイティブ |

**新しい機能はまず HTML 版で試し、使えると分かってからこちらへ移す。**
あちらのほうが手数が少なく壊しても軽いので、思いつきを試すのに向いている。

データは別々（`com.shihbo.worklog` と `com.shihbo.babos-swift`）。
同じ案件を両方で編集することは想定していない。

## なぜ書き直したか

Tauri はブラウザを同梱せず OS のエンジンを借りる——macOS は Safari、
Windows は Edge の。**つまり同じコードが二つの OS で違う挙動をする**うえ、
開発中に見ているのは三つ目の Chrome。

実際に払った代償：`setFullscreen` で3回連続クラッシュ、CSS を触るたび
描画が崩れる、フォントが効いているかを release ビルドで確認できない
（devtools が無い）。どれもコードの誤りではなく、あの構成の代償だった。

ネイティブにすればエンジンの差は消え、状態を端末へ出して確かめられる。
**引き換えに Windows 版は無くなる。**

## 動かす

```bash
./build.sh          # ビルド → .app を組む → 起動
./build.sh --norun  # 組むだけ
```

Swift 6 と macOS SDK が要る。**完全な Xcode は不要**（command line tools で足りる）。

### 生成物を `~/.cache` に置いている理由

このリポジトリは `~/Desktop` にあり、Desktop は iCloud の File Provider の
管理下にある。生成物をそこに置くと、出来たての `.app` に
`com.apple.FinderInfo` が付けられ、codesign が拒否する。
HTML 版はこれで三度足を止められた。

## 同梱しているもの

| フォント | サイズ | 用途 |
|---|---|---|
| Inter（可変） | 856KB | 欧文の本文・見出し |
| IBM Plex Mono | 132KB | 小さいラベルと数字 |
| Noto Sans JP（可変） | 9.1MB | 和文 |
| Noto Sans TC（可変） | 11MB | 中文 |

`Contents/Resources/Fonts` に置き、Info.plist の `ATSApplicationFontsPath` で指す。
macOS が起動時に登録するので `CTFontManager` を叩く必要はない。

**`Font.custom` は1書体しか受け取らない。** Inter だけ指定すると和文は
システム任せ（Hiragino）に落ちるので、CoreText のカスケードリストで
Inter → Noto Sans JP → Noto Sans TC の順に繋いでいる（`Typo.cascaded`）。

## データ

```
~/Library/Application Support/com.shihbo.babos-swift/data.json
```

Codable ＋ ISO8601。400ms のデバウンスで書き、`.atomic` で置き換える。
**起動時に一度書く**——「変更するまで書き込みを試さない」だと、権限や
パスの問題が後になって発覚するため。書き込み状態は設定画面に出る
（成功なら実パス、失敗なら赤字）。

## 触ってはいけないところ

- **気泡にリング・枠線・パーセント表示を足さない。** 大きさと濃さの二軸で足りている
- **濃さは進捗とともに濃くなる。** 逆にすると「始めたばかり」と「もうすぐ終わる」が
  画面上で同じに見える
- **未選択時は「最終更新の案件」を出す。**「気泡をクリックしてください」型の
  空状態は却下済み
- 儀式的な演出は完了アニメーションだけ。他は静かに保つ

判断の経緯と却下した案は HTML 版の `SPEC.md` にある。

## 構成

| ファイル | 中身 |
|---|---|
| `Model.swift` | 案件の型、**二つの編碼式**、配色 |
| `Store.swift` | 状態と操作。画面はこれ経由でしか書き換えない |
| `Field.swift` | 毎フレーム解く物理 |
| `BubbleField.swift` | 気泡の描画と手勢、完了アニメーション |
| `DetailPanel.swift` | 右上のカード、新規案件フォーム |
| `LowerPanes.swift` | サイドバーと一覧 |
| `Sheets.swift` | 設定、完全表示、スライダー |
| `InlineEdit.swift` | その場編集、リンク追加 |
| `Typography.swift` | 書体とフォールバック |
| `Persistence.swift` | 保存と読み込み |
| `ScreenSaver.swift` | 無操作時の画面 |
