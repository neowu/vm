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
        let vms = try FileManager.default.contentsOfDirectory(at: Home.shared.homeDir, includingPropertiesForKeys: [])
        print(
            """
            \("name".padding(16))\("os".padding(16))\("cpu".padding(16))\("memory".padding(16))\("disk".padding(16))\("status".padding(16))
            """)
        for vm in vms {
            let vmDir = Home.shared.vmDir(vm.lastPathComponent)
            if vmDir.initialized {
                let config = try vmDir.config()
                let memory = String(format: "%.2fG", config.memorySizeInGB())
                let disk = String(format: "%.2fG", vmDir.diskUsageInGB())
                let status = vmDir.status()
                print(
                    """
                    \(vmDir.name.padding(16))\(config.os.rawValue.padding(16))\(String(config.cpu).padding(16))\(memory.padding(16))\(disk.padding(16))\(status.padding(16))
                    """)
            }
        }
    }
}
