import Foundation

struct VMDirectory {
    let dir: URL
    let name: String
    let nvramURL: URL
    let diskURL: URL
    let configURL: URL

    init(_ dir: URL) {
        self.dir = dir
        name = dir.lastPathComponent
        nvramURL = dir.appendingPathComponent("nvram.bin")
        diskURL = dir.appendingPathComponent("disk.img")
        configURL = dir.appendingPathComponent("config.json")
    }

    var initialized: Bool {
        File.exists(configURL)
            && File.exists(diskURL)
            && File.exists(nvramURL)
    }

    func resizeDisk(_ sizeInGB: Int) throws {
        if !File.exists(diskURL) {
            FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
        }
        let handle = try FileHandle.init(forWritingTo: diskURL)
        try handle.truncate(atOffset: UInt64(sizeInGB) * 1_000_000_000)
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

    func diskUsageInGB() -> Float {
        return Float(File.diskUsage(diskURL)) / 1_000_000_000
    }

    func status() -> String {
        let lock = FileLock(configURL)!
        return if lock.pid() == nil { "stopped" } else { "running" }
    }
}
