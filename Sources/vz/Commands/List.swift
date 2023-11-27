import ArgumentParser
import Foundation
import Virtualization

struct List: ParsableCommand {
    static var configuration = CommandConfiguration(commandName: "ls", abstract: "list vm status")

    func validate() throws {
        if !Home.shared.homeDir.exists() {
            throw ValidationError("~/.vm not exists")
        }
    }

    func run() throws {
        let vmDirs = Home.shared.vmDirs()
        print(
            """
            \("name".padding(16))\("os".padding(8))\("cpu".padding(8))\("memory".padding(8))\("disk".padding(16))\("status".padding(16))
            """)
        for vmDir in vmDirs {
            let config = try vmDir.loadConfig()
            let memory = String(format: "%.2fG", Float(config.memory) / (1024 * 1024 * 1024))
            let disk = disk(vmDir.diskPath)
            let status = if vmDir.pid() == nil { "stopped" } else { "running" }
            print(
                """
                \(vmDir.name.padding(16))\(config.os.rawValue.padding(8))\(String(config.cpu).padding(8))\(memory.padding(8))\(disk.padding(16))\(status.padding(16))
                """)
        }
    }

    func disk(_ diskPath: Path) -> String {
        let file = try! diskPath.url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .totalFileSizeKey])
        return String(format: "%.2fG/%.0fG", Float(file.totalFileAllocatedSize!) / 1_000_000_000, Float(file.totalFileSize!) / 1_000_000_000)
    }
}
