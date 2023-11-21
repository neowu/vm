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
}
