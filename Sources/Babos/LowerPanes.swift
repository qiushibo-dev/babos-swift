import SwiftUI

// MARK: - 左下：絞り込み

/// 絞り込みは気泡区と列表に同時に効く。両方は常に同じデータの2つの表現。
struct Sidebar: View {
    @Bindable var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                group("ステータス") {
                    row("全部", store.aliveCount, active: store.statusFilter == nil) {
                        store.statusFilter = nil
                    }
                    ForEach(Status.allCases) { s in
                        row(s.label, store.count(s), active: store.statusFilter == s) {
                            store.statusFilter = (store.statusFilter == s) ? nil : s
                        }
                    }
                }

                let types = store.tally(\.type)
                if !types.isEmpty {
                    group("案件タイプ") {
                        row("全部", store.cases.count, active: store.typeFilter == nil) {
                            store.typeFilter = nil
                        }
                        ForEach(types, id: \.0) { name, n in
                            row(name, n, active: store.typeFilter == name) {
                                store.typeFilter = (store.typeFilter == name) ? nil : name
                            }
                        }
                    }
                }

                let clients = store.tally(\.client)
                if !clients.isEmpty {
                    group("クライアント") {
                        row("全部", store.cases.count, active: store.clientFilter == nil) {
                            store.clientFilter = nil
                        }
                        ForEach(clients, id: \.0) { name, n in
                            row(name, n, active: store.clientFilter == name) {
                                store.clientFilter = (store.clientFilter == name) ? nil : name
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        // 左右それぞれが自分のスクロールを持つ。片方を送っても
        // もう片方は動かない（HTML 版 v0.1.9 で直したのと同じ挙動）
        .scrollIndicators(.automatic)
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).metaStyle().padding(.horizontal, 24).padding(.bottom, 4)
            content()
        }
    }

    private func row(_ label: String, _ count: Int, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(active ? .white : Color.mist)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.fog)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(active ? Color.rowSelected : .clear, in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}

// MARK: - 右下：一覧

struct CaseList: View {
    @Bindable var store: Store

    /// 欄位規格。**表頭與內容共用同一份**，分開寫就一定會對不齊。
    /// 名稱欄靠左撐滿，其餘一律置中——`tracking` 會在最後一個字後面留白，
    /// 靠右對齊時那段空白會把表頭推開，跟內容差幾個 px。
    private let cols: [CGFloat] = [92, 108, 118, 104, 64]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.hairline)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if store.listCases.isEmpty {
                        Text("該当する案件がありません。")
                            .metaStyle(12)
                            .padding(.vertical, 40)
                    }
                    ForEach(store.listCases) { c in
                        row(c)
                        Divider().overlay(Color.hairline)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            sortButton(.name).frame(maxWidth: .infinity, alignment: .leading)
            Text("詳細").metaStyle(10).frame(width: cols[0])
            sortButton(.step).frame(width: cols[1])
            sortButton(.status).frame(width: cols[2])
            sortButton(.updated).frame(width: cols[3])
            sortButton(.links).frame(width: cols[4])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func sortButton(_ key: Store.SortKey) -> some View {
        Button {
            if store.sortKey == key {
                store.sortAscending.toggle()
            } else {
                store.sortKey = key
                store.sortAscending = (key == .name)   // 名前だけ昇順が自然
            }
        } label: {
            HStack(spacing: 3) {
                Text(key.label)
                if store.sortKey == key {
                    Text(store.sortAscending ? "↑" : "↓")
                }
            }
            .metaStyle(10)
            .foregroundStyle(store.sortKey == key ? .white : Color.fog)
        }
        .buttonStyle(.plain)
    }

    private func row(_ c: Case) -> some View {
        let selected = store.current?.id == c.id

        return HStack(spacing: 14) {
            // 案件名＋タグ＋重要度
            HStack(spacing: 10) {
                Text(c.name)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text([c.type, c.client].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.fog)
                    .lineLimit(1)

                priorityDots(c)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("詳細")
                .metaStyle(9)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .overlay(Capsule().strokeBorder(Color.slateBody, lineWidth: 1))
                .frame(width: cols[0])

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.haloViolet.opacity(Encoding.opacity(c.progress)))
                    .frame(width: 10, height: 10)
                Text("\(Int(c.progress * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.mist)
            }
            .frame(width: cols[1])

            Button {
                store.toggleWaiting(c.id)
            } label: {
                Text(c.status.label)
                    .metaStyle(9)
                    .foregroundStyle(c.status == .near ? .white : Color.mist)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(
                        c.status == .near ? Color.arcCyan : Color.slateBody, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(width: cols[2])

            Text(c.updated.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.fog)
                .frame(width: cols[3])

            Text("\(c.links.count)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.fog)
                .frame(width: cols[4])
        }
        .padding(.horizontal, 20)
        .frame(height: 50)
        .background(selected ? Color.rowSelected : .clear)
        .contentShape(Rectangle())
        .onTapGesture { store.selectedID = c.id }
    }

    /// 重要度は列表の点だけ。**気泡の大きさには影響させない**（本家で否決済み）
    private func priorityDots(_ c: Case) -> some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { n in
                Circle()
                    .fill(n <= c.priority ? Color.mist : .clear)
                    .overlay(Circle().strokeBorder(Color.slateBody, lineWidth: 1))
                    .frame(width: 6, height: 6)
                    .onTapGesture { store.setPriority(c.id, n) }
            }
        }
    }
}
