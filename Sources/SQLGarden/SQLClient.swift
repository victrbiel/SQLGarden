import Foundation
import Darwin
import SQLBridge
import StudioCore

/// One persistent ODBC session, serialized off the UI thread. A separate
/// instance handles metadata so explorer queries never alter the editor session.
final class SQLClient: @unchecked Sendable {
    // The Microsoft driver detects LC_CTYPE when connecting. In a Finder-
    // launched process the default C locale produced mojibake in live tests.
    // Configure UTF-8 once, before either of our ODBC sessions is created;
    // numeric/date locales and all system preferences remain untouched.
    private static let utf8Configured: Bool = {
        setlocale(LC_CTYPE, "en_US.UTF-8") != nil
    }()
    private let queue = DispatchQueue(label: "sqlgarden.odbc.\(UUID())", qos: .userInitiated)
    private let lock = NSLock()
    private var session: OpaquePointer?
    private var canceled = false

    private func decode(_ pointer: UnsafeMutablePointer<CChar>?) throws -> SQLResponse {
        guard let pointer else { throw StudioError.message("O driver não retornou uma resposta.") }
        defer { sg_string_free(pointer) }
        // Replacement decoding also tolerates a partial codepoint in capped cells.
        let text = String(decoding: UnsafeBufferPointer(start: UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self), count: strlen(pointer)), as: UTF8.self)
        return try JSONDecoder().decode(SQLResponse.self, from: Data(text.utf8))
    }
    func connect(_ profile: ConnectionProfile, password: String) async throws {
        guard Self.utf8Configured else {
            throw StudioError.message("Não foi possível configurar UTF-8 para o driver SQL Server.")
        }
        let connection = try profile.connectionString(password: password)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    self.releaseSession()
                    var error: UnsafeMutablePointer<CChar>?
                    guard let session = sg_session_create(&error) else {
                        let message = error.map { String(cString: $0) } ?? "Não foi possível carregar o driver."
                        if let error { sg_string_free(error) }
                        throw StudioError.message(message)
                    }
                    self.lock.lock(); self.session = session; self.lock.unlock()
                    let response = try connection.withCString { try self.decode(sg_connect(session, $0)) }
                    guard response.success else { throw StudioError.message(response.messages) }
                    continuation.resume()
                } catch { self.releaseSession(); continuation.resume(throwing: error) }
            }
        }
    }
    func execute(_ text: String, timeout: Int = 60, maxRows: Int = 1000) async throws -> SQLResponse {
        let batches = try BatchParser.split(text)
        resetCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    guard let session = self.session else { throw StudioError.message("Conecte ao servidor primeiro.") }
                    var result = SQLResponse()
                    var retainedBytes = 0
                    batchLoop: for batch in batches {
                        for _ in 0..<batch.repetitions {
                            self.lock.lock(); let canceled = self.canceled; self.lock.unlock()
                            if canceled { result.success = false; result.messages += "\nExecução cancelada."; break batchLoop }
                            let part = try batch.sql.withCString {
                                try self.decode(sg_execute(session, $0, UInt32(clamping: timeout), UInt32(clamping: maxRows)))
                            }
                            let bytes = part.sets.reduce(0) { total, set in
                                total + set.rows.reduce(0) { subtotal, row in subtotal + row.reduce(0) { $0 + ($1?.utf8.count ?? 4) } }
                            }
                            guard result.sets.count + part.sets.count <= 64, retainedBytes + bytes <= 32 * 1024 * 1024 else {
                                result.success = false
                                result.messages += "\nLimite total de resultados atingido. O último lote foi executado, mas seu resultado não foi retido. Os próximos lotes não foram executados."
                                break batchLoop
                            }
                            retainedBytes += bytes
                            result.sets += part.sets
                            if !part.messages.isEmpty {
                                result.messages += "\nLote iniciado na linha \(batch.startLine):\n" + part.messages
                            }
                            if !part.success { result.success = false; break batchLoop }
                        }
                    }
                    continuation.resume(returning: result)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
    func cancel() {
        lock.lock(); canceled = true
        // Keep the pointer alive until SQLCancel returns. No ODBC connection
        // is freed concurrently with this section.
        if let session { sg_cancel(session) }
        lock.unlock()
    }
    private func resetCancellation() {
        lock.lock(); canceled = false; lock.unlock()
    }
    func disconnect() async {
        await withCheckedContinuation { continuation in
            queue.async { self.releaseSession(); continuation.resume() }
        }
    }
    func currentDatabase() async -> String? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let session = self.session, let value = sg_current_database(session) else {
                    continuation.resume(returning: nil); return
                }
                let name = String(cString: value); sg_string_free(value)
                continuation.resume(returning: name)
            }
        }
    }
    private func releaseSession() {
        lock.lock(); let old = session; session = nil; lock.unlock()
        if let old { sg_session_free(old) }
    }
    deinit { if let session { sg_session_free(session) } }
}
