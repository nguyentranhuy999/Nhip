import SwiftUI
import NhipCore

struct DashboardSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var validationError: String?
    private var page: DashboardPage { model.dashboardSettingsPage }
    private var selected: [UUID] { DashboardSelection.selectedIDs(for: page, journal: model.journal) }
    private var selectedActivities: [Activity] { selected.compactMap { model.journal.activity($0) } }
    private var remaining: [Activity] { model.journal.activities.filter { !selected.contains($0.id) } }

    var body: some View {
        Card(title: "Hoạt động trên dashboard") {
            HStack {
                Picker("Mục", selection: $model.dashboardSettingsPage) {
                    ForEach(DashboardPage.allCases) { page in Text(page.title(in: model.journal.preferences)).tag(page) }
                }.frame(maxWidth: 350)
                Spacer()
                Text("\(selected.count)/\(DashboardSelection.maximum) hoạt động").monospacedDigit().foregroundStyle(.secondary)
            }
            ForEach(Array(selectedActivities.enumerated()), id: \.element.id) { index, activity in
                HStack {
                    activityButton(activity, selected: true)
                    Button { move(activity.id, by: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0).accessibilityLabel("Đưa \(activity.name) lên")
                    Button { move(activity.id, by: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == selected.count - 1).accessibilityLabel("Đưa \(activity.name) xuống")
                }
            }
            if !selectedActivities.isEmpty && !remaining.isEmpty { Divider() }
            ForEach(remaining) { activity in
                activityButton(activity, selected: false)
                    .disabled(selected.count >= DashboardSelection.maximum)
                    .help(selected.count >= DashboardSelection.maximum ? "Đã chọn tối đa 6 hoạt động" : "Thêm vào dashboard")
            }
            if let validationError { Text(validationError).font(.callout).foregroundStyle(.red) }
            Divider()
            Button("Chọn lại 3 hoạt động mặc định") { save(DashboardSelection.defaultIDs(model.journal)) }
        }.onChange(of: model.dashboardSettingsPage) { _ in validationError = nil }
    }
    private func activityButton(_ activity: Activity, selected isSelected: Bool) -> some View {
        Button {
            var ids = selected
            if isSelected { ids.removeAll { $0 == activity.id } }
            else { ids.append(activity.id) }
            save(ids)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.indigo : Color.secondary).frame(width: 20)
                Label(activity.name, systemImage: activity.symbol).foregroundStyle(Color(hex: activity.color))
                    .lineLimit(1).truncationMode(.tail)
                if activity.archived { Text("Đã lưu trữ").font(.caption).foregroundStyle(.secondary) }
                Spacer()
            }.padding(.vertical, 8).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("\(isSelected ? "Bỏ chọn" : "Chọn") \(activity.name)")
            .accessibilityValue(isSelected ? "Đã chọn" : "Chưa chọn")
    }
    private func move(_ id: UUID, by offset: Int) {
        var ids = selected
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset) else { return }
        ids.swapAt(index, index + offset); save(ids)
    }
    private func save(_ ids: [UUID]) {
        var draft = model.journal
        do {
            try DashboardSelection.setSelected(ids, for: page, journal: &draft)
            if model.perform({ $0 = draft }) { validationError = nil }
        } catch { validationError = error.localizedDescription }
    }
}
