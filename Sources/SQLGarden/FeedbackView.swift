import AppKit
import SwiftUI
import StudioCore

@MainActor final class SupportMailer: NSObject, ObservableObject, NSSharingServiceDelegate {
    @Published var status: String?
    private var service: NSSharingService?
    func prepare(report: String, kind: String) {
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SQLGarden-Support-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let attachment = directory.appendingPathComponent("SQLGarden-relatorio.txt")
            try Data(report.utf8).write(to: attachment, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: attachment.path)
            let items: [Any] = [report, attachment]
            guard let composer = NSSharingService(named: .composeEmail), composer.canPerform(withItems: items) else {
                try? FileManager.default.removeItem(at: directory)
                status = "Não há um serviço de e-mail disponível. Copie ou salve o relatório e envie para \(SupportReport.recipient) pelo seu e-mail."
                return
            }
            service = composer; composer.delegate = self
            composer.recipients = [SupportReport.recipient]
            composer.subject = "SQLGarden \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.1") — \(kind)"
            status = "Composição solicitada ao macOS. Confira o destinatário, o texto e o anexo no aplicativo de e-mail e envie por lá. O SQLGarden não confirma a entrega."
            composer.perform(withItems: items)
            // The mail app may read the attachment after the composer opens.
            // Keep its private temporary file available for the OS temporary-file lifecycle.
        } catch { status = "Não foi possível preparar o anexo. Use Copiar relatório ou Salvar relatório." }
    }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        status = "O serviço de e-mail não concluiu a composição. Copie ou salve o relatório para enviar manualmente."
    }
    func save(_ report: String) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "SQLGarden-relatorio.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try report.write(to: url, atomically: true, encoding: .utf8); status = "Relatório salvo. Envie para \(SupportReport.recipient) quando desejar." }
        catch { status = "Não foi possível salvar o relatório no local escolhido." }
    }
}
@MainActor struct FeedbackView: View {
    @EnvironmentObject var workspace: Workspace
    @Environment(\.dismiss) var dismiss
    @StateObject private var mailer = SupportMailer()
    @State private var kind = "Relatar problema"
    @State private var description = ""
    @State private var steps = ""
    @State private var includeDiagnostic = false
    @State private var reviewed = ""
    @State private var reviewing = false
    private var diagnostic: String {
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        return SupportReport.diagnostic(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.1",
            system: ProcessInfo.processInfo.operatingSystemVersionString, architecture: architecture,
            missing: RuntimeDependencies.missing, events: workspace.diagnosticEvents)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(reviewing ? "Revise o relatório completo" : "Feedback e problemas").font(.title2.bold())
                Spacer(); Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Destinatário: \(SupportReport.recipient)").textSelection(.enabled)
            if reviewing {
                Text("Tudo abaixo será colocado no corpo do e-mail e no anexo TXT. Edite ou remova qualquer informação antes de continuar.")
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $reviewed).font(.system(size: 12, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))
                if let status = mailer.status { Text(status).font(.callout).textSelection(.enabled) }
                HStack {
                    Button("Voltar") { reviewing = false; mailer.status = nil }
                    Button("Copiar relatório") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(reviewed, forType: .string)
                        mailer.status = "Relatório copiado. Cole no seu e-mail quando desejar."
                    }
                    Button("Salvar relatório…") { mailer.save(reviewed) }
                    Spacer()
                    Button("Preparar e-mail…") { mailer.prepare(report: reviewed, kind: kind) }
                        .buttonStyle(.borderedProminent).disabled(reviewed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Picker("Tipo", selection: $kind) {
                    Text("Relatar problema").tag("Relatar problema")
                    Text("Enviar sugestão").tag("Enviar sugestão")
                }.pickerStyle(.segmented)
                Text("Descrição").font(.headline)
                TextEditor(text: $description).frame(minHeight: 100).border(Color.secondary.opacity(0.3))
                Text("Passos para reproduzir / o que você esperava").font(.headline)
                TextEditor(text: $steps).frame(minHeight: 80).border(Color.secondary.opacity(0.3))
                Toggle("Incluir diagnóstico técnico desta abertura (opcional)", isOn: $includeDiagnostic)
                Text("Somente versão, macOS, arquitetura, dependências ausentes e eventos técnicos. Não inclui SQL, resultados, senhas, servidor, banco ou mensagens brutas de erro. Revise também o que você escreveu nos campos acima.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Nenhum envio automático. Você confirma o envio no aplicativo de e-mail. Também pode copiar ou salvar o relatório para usar um webmail.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Revisar relatório") {
                        reviewed = SupportReport.compose(kind: kind, description: description, steps: steps,
                            diagnostic: includeDiagnostic ? diagnostic : nil)
                        reviewing = true
                    }.buttonStyle(.borderedProminent).disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }.padding(22).frame(width: 760, height: 620)
    }
}
