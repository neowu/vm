import Foundation

struct File {
  static func createDirectory(_ path: URL) throws {
    Logger.info("create dir, dir=\(path)")
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
  }

  static func exists(_ path: URL) -> Bool {
    return FileManager.default.fileExists(atPath: path.path())
  }

  static func move(_ from: URL, _ to: URL) throws {
    Logger.info("move dir, from=\(from), to=\(to)")
    try FileManager.default.moveItem(at: from, to: to)
  }
}
