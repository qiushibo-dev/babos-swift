# Babos (Swift)

[Babos](https://github.com/qiushibo-dev/work-log) 的 SwiftUI 重寫版。**實驗中，不是替代品**——
HTML／Tauri 那版還在用，這邊做壞了沒有損失。

## 為什麼重寫

原版是單一 HTML 檔用 Tauri 包成 app。Tauri 不帶瀏覽器，借系統的引擎——
macOS 借 Safari 的、Windows 借 Edge 的。**所以同一份程式在兩個系統上行為不一樣**，
而開發時在 Chrome 裡測，那又是第三種。

這造成的實際損失：`setFullscreen` 連續三次讓 app 閃退、CSS 一改就崩、
字體到底有沒有生效無法驗證（release build 沒有 devtools）。
全部都不是程式寫錯，是那個架構的代價。

換成原生之後：沒有 WebView，沒有引擎差異，狀態可以直接印出來看。
代價是 **Windows 版沒有了**。

## 現在做到哪

**第一階段（能跑）**

- 氣泡的物理：碰撞推擠、中心力、邊界反彈、微幅晃動、拖曳與放手後的慣性
- 大小與深淺的兩條公式，數值原封不動搬過來
- 點選氣泡 → 下方出現 1–10 進度節點，點下去氣泡即時改變

**還沒有**

- 字體（現在是系統預設，原版是 Inter + Noto Sans JP/TC）
- 下半部的列表與側欄篩選
- 右側詳細卡片（工作日誌、連結、備註）
- 資料儲存（現在寫死假資料，還沒讀 `work-tracker.json`）
- 三語系、兩種配色、螢幕保護、完成動畫

## 跑起來

```bash
./build.sh          # 編譯 → 組成 .app → 開起來
./build.sh --norun  # 只編譯打包
```

需要 Swift 6 與 macOS SDK，**不需要完整的 Xcode**（command line tools 就夠）。

### 建置產物刻意放在 `~/.cache`

這個專案在 `~/Desktop`，而桌面在 iCloud 的 File Provider 管理下。
生成物留在那裡的話，剛做好的 `.app` 會被同步機制加上 `com.apple.FinderInfo`，
codesign 直接拒絕簽章。原版為了這件事被卡了三次才查出根因。

## 檔案

| 檔案 | 內容 |
|---|---|
| `Sources/Babos/Model.swift` | 案件資料結構、**兩條編碼公式**、配色 |
| `Sources/Babos/Field.swift` | 每幀解算的物理場 |
| `Sources/Babos/BubbleField.swift` | 氣泡的畫面與手勢 |
| `Sources/Babos/BabosApp.swift` | 進入點與暫時的假資料 |

## 不要動的地方

氣泡的兩個編碼互相獨立，這是整個 app 的核心：

- **大小** ＝ 這件案子現在佔掉多少腦袋。走常態曲線（小 → 大 → 小），
  因為設計最耗神的是中段，收尾剩下的多半是機械性動作
- **深淺** ＝ 已經走了多遠。單調遞增

兩者不能同方向衰減，否則「剛開始」與「快結束」在畫面上會長得一樣。
完整的決策紀錄（以及被否決的方案）在原版的 `SPEC.md`。
