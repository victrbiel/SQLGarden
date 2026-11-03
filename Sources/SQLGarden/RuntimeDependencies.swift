import Foundation

/// Checks only public library paths; never reads profiles or credentials.
enum RuntimeDependencies {
    static var missing: [String] {
        #if arch(arm64)
        let prefix = "/opt/homebrew"
        #else
        let prefix = "/usr/local"
        #endif
        let libraries = [
            ("unixODBC", "opt/unixodbc/lib/libodbc.2.dylib"),
            ("OpenSSL 3", "opt/openssl@3/lib/libssl.3.dylib"),
            ("Microsoft ODBC Driver 18", "opt/msodbcsql18/lib/libmsodbcsql.18.dylib")
        ]
        return libraries.compactMap { name, path in
            FileManager.default.isReadableFile(atPath: prefix + "/" + path) ? nil : name
        }
    }
}
