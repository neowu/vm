import Foundation

struct Home {
    static let shared = Home()

    let homeDir: Path

    init() {
        homeDir = Path("~/.vm")
    }

    func createTempVMDirectory() throws -> VMDirectory {
        let tempDir = homeDir.directory(UUID().uuidString)
        Logger.info("create dir, dir=\(tempDir)")
        try FileManager.default.createDirectory(at: tempDir.url, withIntermediateDirectories: true)
        return VMDirectory(tempDir)
    }

    func vmDir(_ name: String) -> VMDirectory {
        return VMDirectory(homeDir.directory(name))
    }

    func vmDirs() -> [VMDirectory] {
        if !homeDir.exists() {
            return []
        }
        let vms = try! FileManager.default.contentsOfDirectory(at: homeDir.url, includingPropertiesForKeys: [])
        return vms.compactMap({
            let dir = vmDir($0.lastPathComponent)
            return if dir.initialized() { dir } else { nil }
        })
    }
}
