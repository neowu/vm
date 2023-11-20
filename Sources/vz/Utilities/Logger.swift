struct Logger {
  static func info(_ message: String) {
    print("[info] \(message)")
  }

  static func error(_ message: String) {
    print("[ERROR] \(message)")
  }
}
