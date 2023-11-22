import Foundation

struct Logger {
    static func info(_ message: String) {
        print("[info] \(message)")
        fflush(stdout)
    }

    static func error(_ message: String) {
        print("[ERROR] \(message)")
        fflush(stdout)
    }
}
