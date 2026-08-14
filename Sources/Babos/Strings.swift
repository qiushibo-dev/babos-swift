import Foundation

enum Lang: String, CaseIterable, Identifiable {
    case en, ja, zh
    var id: String { rawValue }
    var label: String {
        switch self {
        case .en: "English"
        case .ja: "日本語"
        case .zh: "繁體中文"
        }
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case ameba, mono
    var id: String { rawValue }
}

/// 全部の表示文字列をここに集約する。HTML 版の STRINGS をそのまま移した。
/// 画面側に日本語を直書きしないこと——切り替えが効かなくなる。
struct L: Sendable {
    var searchPh, newCaseBtn: String
    var legendStart, legendEnd: String
    var colCase, detail, progress, colStatus, colUpdated, links: String
    var newCase, newCaseHint, newCaseHintFirst: String
    var fieldName, fieldType, fieldClient: String
    var phName, phType, phClient, create: String
    var worklog, noLogs, phLog: String
    var addLink, deleteCase, backToCase, toNewForm: String
    var statusGroup, typeGroup, clientGroup: String
    var all, active, idle, near, done: String
    var noBubbles, noCasesYet, noRows: String
    var notes, fullLog, phMemo: String
    var save, saved, close, cancel, add: String
    var screensaver, ssOff, minUnit, saverCases: String
    var settings, language, theme, themeAmeba, themeMono: String
    var tagManagement, about, tagHint, tagAdd, phTag, noTags: String
    var storageFailed, storagePending, storageLocal: String
    var version, author, storage: String
    var linkType, linkPath, phUrl, addLinkTitle: String
    // クロージャは @Sendable でないと L 全体が Sendable にならず、
    // static let で持てない（Swift 6 の並行性チェック）
    var confirmFinish: @Sendable (String) -> String
    var confirmDelete: @Sendable (String) -> String

    static func of(_ l: Lang) -> L {
        switch l {
        case .en: en
        case .ja: ja
        case .zh: zh
        }
    }

    static let en = L(
        searchPh: "Search cases…", newCaseBtn: "＋ New case",
        legendStart: "Started", legendEnd: "Near done",
        colCase: "Case", detail: "Detail", progress: "Progress",
        colStatus: "Status", colUpdated: "Updated", links: "Links",
        newCase: "New case",
        newCaseHint: "Once created, this case appears as a bubble on the left.",
        newCaseHintFirst: "Add your first case to get started.",
        fieldName: "Case name", fieldType: "Type", fieldClient: "Client",
        phName: "e.g. Acme landing page", phType: "e.g. LinkedIn / Print / Banner",
        phClient: "e.g. Acme / Internal", create: "Create",
        worklog: "Work log", noLogs: "No entries yet.", phLog: "Add an entry…",
        addLink: "＋ Add link", deleteCase: "Delete case",
        backToCase: "Back to case", toNewForm: "New case form",
        statusGroup: "Status", typeGroup: "Type", clientGroup: "Client",
        all: "All", active: "Active", idle: "Waiting", near: "Near done", done: "Done",
        noBubbles: "No cases match this filter.",
        noCasesYet: "No cases yet. Use the form on the right to add your first one.",
        noRows: "No cases match this filter.",
        notes: "Notes", fullLog: "Work log (read only)",
        phMemo: "Anything worth keeping about this case — direction, decisions, things to watch.",
        save: "Save", saved: "Saved", close: "Close", cancel: "Cancel", add: "Add",
        screensaver: "Screen saver", ssOff: "Off", minUnit: " min", saverCases: " active cases",
        settings: "Settings", language: "Language",
        theme: "Colour", themeAmeba: "Midnight", themeMono: "Greyscale",
        tagManagement: "Tags", about: "About",
        tagHint: "Tags you type when creating a case are added here automatically.",
        tagAdd: "Add", phTag: "New tag…", noTags: "No tags yet.",
        storageFailed: "File write failed", storagePending: "Not written yet",
        storageLocal: "Memory only", version: "Version", author: "Built by", storage: "Storage",
        linkType: "Type", linkPath: "Path or URL", phUrl: "https://…  or  file:///Users/…",
        addLinkTitle: "Add link",
        confirmFinish: { "Mark “\($0)” as done?" },
        confirmDelete: { "Delete “\($0)”? This cannot be undone." })

    static let ja = L(
        searchPh: "案件を検索…", newCaseBtn: "＋ 新規案件",
        legendStart: "着手", legendEnd: "完了直前",
        colCase: "案件名", detail: "詳細", progress: "進捗",
        colStatus: "ステータス", colUpdated: "最終更新", links: "リンク",
        newCase: "新規案件",
        newCaseHint: "作成すると、この案件が左側に気泡として現れます。",
        newCaseHintFirst: "まずは1件目を登録してください。",
        fieldName: "案件名", fieldType: "案件タイプ", fieldClient: "クライアント",
        phName: "例：A社 LP", phType: "例：LinkedIn ／ 印刷物 ／ バナー",
        phClient: "例：A社 ／ 社内", create: "作成",
        worklog: "作業ログ", noLogs: "まだログがありません。", phLog: "ログを追加…",
        addLink: "＋ リンクを追加", deleteCase: "この案件を削除",
        backToCase: "案件表示に戻る", toNewForm: "新規案件フォームへ",
        statusGroup: "ステータス", typeGroup: "案件タイプ", clientGroup: "クライアント",
        all: "全部", active: "進行中", idle: "待機", near: "完了間近", done: "完了",
        noBubbles: "該当する案件がありません。",
        noCasesYet: "案件がまだありません。右のフォームから1件目を登録してください。",
        noRows: "該当する案件がありません。",
        notes: "メモ", fullLog: "作業ログ（表示のみ）",
        phMemo: "この案件について残しておきたいこと——方向性、決定事項、注意点など。",
        save: "保存", saved: "保存しました", close: "閉じる", cancel: "キャンセル", add: "追加",
        screensaver: "スクリーンセーバー", ssOff: "オフ", minUnit: "分", saverCases: " 件 進行中",
        settings: "設定", language: "言語",
        theme: "配色", themeAmeba: "ミッドナイト", themeMono: "グレースケール",
        tagManagement: "タグ管理", about: "このアプリについて",
        tagHint: "案件作成時に入力したタグは自動でここに追加されます。",
        tagAdd: "追加", phTag: "新しいタグ…", noTags: "まだタグがありません。",
        storageFailed: "ファイル書き込み失敗", storagePending: "まだ書き込まれていません",
        storageLocal: "メモリのみ", version: "バージョン", author: "制作", storage: "保存先",
        linkType: "種類", linkPath: "パス ／ URL", phUrl: "https://… または file:///Users/…",
        addLinkTitle: "リンクを追加",
        confirmFinish: { "「\($0)」を完了にしますか？" },
        confirmDelete: { "「\($0)」を削除しますか？　元に戻せません。" })

    static let zh = L(
        searchPh: "搜尋案件…", newCaseBtn: "＋ 新增案件",
        legendStart: "剛開始", legendEnd: "接近完成",
        colCase: "案件名稱", detail: "詳細", progress: "進度",
        colStatus: "狀態", colUpdated: "最後更新", links: "連結",
        newCase: "新增案件",
        newCaseHint: "建立後，這個案件會以泡泡的形式出現在左邊。",
        newCaseHintFirst: "先建立第一個案件吧。",
        fieldName: "案件名稱", fieldType: "案件類型", fieldClient: "客戶",
        phName: "例：A社 LP", phType: "例：LinkedIn ／ 印刷品 ／ Banner",
        phClient: "例：A社 ／ 內部", create: "建立",
        worklog: "工作紀錄", noLogs: "還沒有任何紀錄。", phLog: "新增一筆紀錄…",
        addLink: "＋ 新增連結", deleteCase: "刪除這個案件",
        backToCase: "回到案件", toNewForm: "新增案件表單",
        statusGroup: "狀態", typeGroup: "案件類型", clientGroup: "客戶",
        all: "全部", active: "進行中", idle: "等待中", near: "接近完成", done: "已完成",
        noBubbles: "沒有符合這個篩選的案件。",
        noCasesYet: "還沒有案件。用右邊的表單建立第一個。",
        noRows: "沒有符合這個篩選的案件。",
        notes: "備註", fullLog: "工作紀錄（唯讀）",
        phMemo: "關於這個案件值得記下來的事——方向、決定、要注意的地方。",
        save: "儲存", saved: "已儲存", close: "關閉", cancel: "取消", add: "新增",
        screensaver: "螢幕保護", ssOff: "關閉", minUnit: " 分鐘", saverCases: " 件進行中",
        settings: "設定", language: "語言",
        theme: "配色", themeAmeba: "午夜藍", themeMono: "灰階",
        tagManagement: "標籤管理", about: "關於",
        tagHint: "建立案件時輸入的標籤會自動加到這裡。",
        tagAdd: "新增", phTag: "新標籤…", noTags: "還沒有標籤。",
        storageFailed: "檔案寫入失敗", storagePending: "尚未寫入",
        storageLocal: "只在記憶體裡", version: "版本", author: "製作", storage: "資料儲存位置",
        linkType: "類型", linkPath: "路徑或網址", phUrl: "https://… 或 file:///Users/…",
        addLinkTitle: "新增連結",
        confirmFinish: { "要把「\($0)」標記為完成嗎？" },
        confirmDelete: { "要刪除「\($0)」嗎？　這個動作無法復原。" })
}
