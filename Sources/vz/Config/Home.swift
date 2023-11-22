import ArgumentParser
import Foundation

struct Home {
    static let shared = Home()

    let homeDir: URL

    init() {
        homeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vm", isDirectory: true)
    }

    func createTempVMDirectory() throws -> VMDirectory {
        let tempDir = homeDir.appendingPathComponent(UUID().uuidString)
        try File.createDirectory(tempDir)
        return VMDirectory(tempDir)
    }

    func vmDir(_ name: String) -> VMDirectory {
        return VMDirectory(homeDir.appendingPathComponent(name, isDirectory: true))
    }

    func vmDirs() -> [VMDirectory] {
        if !File.exists(homeDir) {
            return []
        }
        let vms = try! FileManager.default.contentsOfDirectory(at: homeDir, includingPropertiesForKeys: [])
        return vms.compactMap({
            let vmDir = vmDir($0.lastPathComponent)
            return if vmDir.initialized() { vmDir } else { nil }
        })
    }
}
