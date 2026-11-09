import AppKit
import SwiftUI
import NhipCore

extension InterfaceSection {
    func displaySymbol(in preferences: Preferences) -> String {
        let name = symbol(in: preferences)
        if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil { return name }
        if NSImage(systemSymbolName: defaultSymbol, accessibilityDescription: nil) != nil { return defaultSymbol }
        return fallbackSymbol
    }
}

struct InterfaceIconEditor: View {
    @ObservedObject var model: AppModel
    let section: InterfaceSection
    @State private var name: String
    @State private var symbol: String
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, section: InterfaceSection) {
        self.model = model; self.section = section
        _name = State(initialValue: section.title(in: model.journal.preferences))
        _symbol = State(initialValue: section.displaySymbol(in: model.journal.preferences))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sửa mục \(section.title)").font(.title2.bold())
            TextField("Tên mục", text: $name, prompt: Text(section.title)).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Tên mục \(section.title)")
            SymbolPicker(selection: $symbol)
            HStack {
                Button("Mặc định") { name = section.title; symbol = section.defaultSymbol }
                Spacer()
                Button("Hủy") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Lưu") {
                    if model.perform({ section.setTitle(name, in: &$0.preferences); section.setSymbol(symbol, in: &$0.preferences) }) { dismiss() }
                }.buttonStyle(.borderedProminent)
                    .disabled(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) == nil)
            }
        }.padding(24).frame(width: 620)
    }
}
