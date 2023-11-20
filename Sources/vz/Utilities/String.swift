import Foundation

extension String {
  func padding(_ toLength: Int) -> String {
    return self.padding(toLength: toLength, withPad: " ", startingAt: 0)
  }

  func toFileURL() -> URL {
    return URL(filePath: NSString(string: self).expandingTildeInPath)
  }
}
