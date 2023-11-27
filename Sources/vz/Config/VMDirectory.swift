import Foundation

struct VMDirectory {
    let dir: Path
    let nvramPath: Path
    let diskPath: Path
    let configPath: Path

    init(_ dir: Path) {
        self.dir = dir
        nvramPath = dir.file("nvram.bin")
        diskPath = dir.file("disk.img")
        configPath = dir.file("config.json")
    }

    var name: String {
        return dir.name
    }

    func initialized() -> Bool {
        configPath.exists() && diskPath.exists() && nvramPath.exists()
    }

    func resizeDisk(_ size: UInt64) throws {
        if !diskPath.exists() {
            FileManager.default.createFile(atPath: diskPath.path, contents: nil, attributes: nil)
        }
        let handle = try FileHandle.init(forWritingTo: diskPath.url)
        try handle.truncate(atOffset: size)
        try handle.close()
    }

    func saveConfig(_ config: VMConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        FileManager.default.createFile(atPath: configPath.path, contents: data)
    }

    func loadConfig() throws -> VMConfig {
        let data = FileManager.default.contents(atPath: configPath.path)
        let decoder = JSONDecoder()
        return try decoder.decode(VMConfig.self, from: data!)
    }

    func pid() -> pid_t? {
        if let lock = FileLock(configPath) {
            return lock.pid()
        }
        return nil
    }

    func lock() -> FileLock? {
        if let lock = FileLock(configPath), lock.lock() {
            return lock
        }
        return nil
    }
}
