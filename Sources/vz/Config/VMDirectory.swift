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

    func initialized() -> Bool {
        File.exists(configURL) && File.exists(diskURL) && File.exists(nvramURL)
    }

    func resizeDisk(_ sizeInGB: Int) throws {
        if !File.exists(diskURL) {
            FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
        }
        let handle = try FileHandle.init(forWritingTo: diskURL)
        try handle.truncate(atOffset: UInt64(sizeInGB) * 1_000_000_000)
        try handle.close()
    }

    func saveConfig(_ config: VMConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        FileManager.default.createFile(atPath: configURL.path, contents: data)
    }

    func loadConfig() throws -> VMConfig {
        let data = FileManager.default.contents(atPath: configURL.path)
        let decoder = JSONDecoder()
        return try decoder.decode(VMConfig.self, from: data!)
    }

    func pid() -> pid_t? {
        if let lock = FileLock(configURL) {
            return lock.pid()
        }
        return nil
    }

    func lock() -> FileLock? {
        if let lock = FileLock(configURL), lock.lock() {
            return lock
        }
        return nil
    }
}
