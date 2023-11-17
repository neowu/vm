import Foundation

public protocol Logger {
  func appendNewLine(_ line: String) -> Void
  func updateLastLine(_ line: String) -> Void
}

var defaultLogger: Logger = SimpleConsoleLogger()

public class SimpleConsoleLogger: Logger {
  public init() {
  }

  public func appendNewLine(_ line: String) {
    print(line, terminator: "\n")
  }

  public func updateLastLine(_ line: String) {
    print(line, terminator: "\n")
  }
}
