import SwiftUI

struct SymbolPicker: View {
    @Binding var selection: String
    var tint: Color = .indigo
    @State private var query = ""
    @State private var group: ActivitySymbolGroup = .all
    @State private var available: [ActivitySymbol] = []
    @State private var loading = true
    private var symbols: [ActivitySymbol] { ActivitySymbols.matching(query, group: group, in: available) }

    var body: some View {
        let results = symbols
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Biểu tượng").font(.headline)
                Spacer()
                Image(systemName: selection).foregroundStyle(tint)
                Text(available.first { $0.name == selection }?.title ?? "Hiện tại")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: 300, alignment: .trailing)
            }
            HStack(spacing: 10) {
                TextField("Tìm biểu tượng", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("Tìm biểu tượng")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).accessibilityLabel("Xóa tìm kiếm")
                }
                Picker("Nhóm biểu tượng", selection: $group) {
                    ForEach(ActivitySymbolGroup.allCases) { item in Text(item.title).tag(item) }
                }.labelsHidden().frame(width: 180).accessibilityLabel("Nhóm biểu tượng")
            }
            Text(loading ? "Đang tải biểu tượng…" : "\(results.count) biểu tượng").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if results.isEmpty {
                    Text("Không tìm thấy biểu tượng").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        ForEach(results) { symbol in
                            Button { selection = symbol.name } label: {
                                Image(systemName: symbol.name).font(.system(size: 20))
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .foregroundStyle(selection == symbol.name ? tint : Color.primary)
                                    .background(selection == symbol.name ? tint.opacity(0.15) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(selection == symbol.name ? tint : .clear, lineWidth: 1.5))
                            }.buttonStyle(.plain).help(symbol.title).accessibilityLabel("Biểu tượng \(symbol.title)")
                                .accessibilityValue(selection == symbol.name ? "Đang chọn" : "")
                        }
                    }.padding(3)
                }
            }.frame(height: 230).id(group.rawValue + ":" + query)
        }.task {
            let catalog = await Task.detached(priority: .userInitiated) { ActivitySymbols.all }.value
            guard !Task.isCancelled else { return }
            available = catalog; loading = false
        }
    }
}
