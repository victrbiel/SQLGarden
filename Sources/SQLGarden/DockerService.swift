import Foundation
import StudioCore

struct ContainerInfo: Decodable, Identifiable, Hashable {
    let Names: String
    let State: String
    let Status: String
    let Image: String
    var id: String { Names }
    var running: Bool { State == "running" }
}

enum DockerService {
    static func run(_ arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            let paths = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "/Applications/Docker.app/Contents/Resources/bin/docker", NSHomeDirectory() + "/.docker/bin/docker"]
            guard let path = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                throw StudioError.message("Docker não encontrado. Instale ou abra o Docker Desktop e tente novamente.")
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe; process.standardError = pipe
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self)
            guard process.terminationStatus == 0 else {
                throw StudioError.message(output.isEmpty ? "O Docker retornou um erro." : output)
            }
            return output
        }.value
    }
    static func list() async throws -> [ContainerInfo] {
        let output = try await run(["ps", "--all", "--format", "{{json .}}"])
        return try output.split(separator: "\n").map {
            try JSONDecoder().decode(ContainerInfo.self, from: Data($0.utf8))
        }
    }
    static func control(_ action: String, name: String) async throws {
        guard ["start", "stop"].contains(action), !name.isEmpty, !name.hasPrefix("-"),
              name.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9_.-]*$"#, options: .regularExpression) != nil else {
            throw StudioError.message("Nome de container inválido.")
        }
        _ = try await run([action, name])
    }
}
