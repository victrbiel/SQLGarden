import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }
    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon).resizable().scaledToFit().frame(width: 88, height: 88)
            }
            SQLGardenLogo().frame(width: 260, height: 88)
            Text("Versão \(version)").font(.subheadline).foregroundStyle(.secondary)
            Text("Desenvolvido por Victor").font(.title3.bold())
            Text("Interface nativa para SQL Server Express\nCódigo aberto • Licença MIT")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("Copyright © 2026 Victor.").font(.caption).foregroundStyle(.secondary)
            Button("Fechar") { dismiss() }.keyboardShortcut(.defaultAction)
        }.padding(28).frame(width: 430)
    }
}
