import Foundation

struct Logger {
    static let pid = getpid()
    static let formatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    static func info(_ message: String) {
        print("\(formatter.string(from: Date())) INFO [\(pid)] \(message)")
        fflush(stdout)
    }

    static func error(_ message: String) {
        fputs("\(formatter.string(from: Date())) ERROR [\(pid)] \(message)\n", stderr)
        fflush(stderr)
    }
}
