import Foundation

struct Logger {
    static func info(_ message: String) {
        print("[info] \(message)")
        fflush(stdout)
    }

    static func error(_ message: String) {
        fputs("[ERROR] \(message)\n", stderr)
        fflush(stderr)
    }
}
