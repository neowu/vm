import Foundation

struct VMDirectory {
  let dir: URL
  let nvramURL: URL
  let diskURL: URL
  let configURL: URL

  init(_ dir: URL) {
    self.dir = dir
    nvramURL = dir.appendingPathComponent("nvram.bin")
    diskURL = dir.appendingPathComponent("disk.img")
    configURL = dir.appendingPathComponent("config.json")
  }

  func exists() -> Bool {
    return File.exists(dir)
  }

  func resizeDisk(_ sizeInGB: Int) throws {
    if !File.exists(diskURL) {
      FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
    }
    let handle = try FileHandle.init(forWritingTo: diskURL)
    try handle.truncate(atOffset: UInt64(sizeInGB) * 1000 * 1000 * 1000)
    try handle.close()
  }

  func saveConfig(config: VMConfig) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(config)
    FileManager.default.createFile(atPath: configURL.path, contents: data)
  }

  func config() throws -> VMConfig {
    let data = FileManager.default.contents(atPath: configURL.path)
    let decoder = JSONDecoder()
    return try decoder.decode(VMConfig.self, from: data!)
  }
}
