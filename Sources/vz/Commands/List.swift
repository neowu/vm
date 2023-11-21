import ArgumentParser
import Foundation
import Virtualization

struct List: ParsableCommand {
    static var configuration = CommandConfiguration(commandName: "ls", abstract: "list vm status")

    func validate() throws {
        if !File.exists(Home.shared.homeDir) {
            throw ValidationError("~/.vm not exists")
        }
    }

    func run() throws {
        let vmDirs = Home.shared.vmDirs()
        print(
            """
            \("name".padding(16))\("os".padding(16))\("cpu".padding(16))\("memory".padding(16))\("disk".padding(16))\("status".padding(16))
            """)
        for vmDir in vmDirs {
            let config = try vmDir.config()
            let memory = String(format: "%.2fG", config.memorySizeInGB())
            let disk = disk(vmDir.diskURL)
            let status = vmDir.status()
            print(
                """
                \(vmDir.name.padding(16))\(config.os.rawValue.padding(16))\(String(config.cpu).padding(16))\(memory.padding(16))\(disk.padding(16))\(status.padding(16))
                """)
        }
    }

    func disk(_ path: URL) -> String {
        let file = try! path.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .totalFileSizeKey])
        return String(format: "%.2fG/%.0fG", Float(file.totalFileAllocatedSize!) / 1_000_000_000, Float(file.totalFileSize!) / 1_000_000_000)
    }
}
