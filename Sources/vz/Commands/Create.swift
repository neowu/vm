import ArgumentParser
import Foundation
import Virtualization

enum OSOption: String, ExpressibleByArgument {
    case linux, macOS
}

struct Create: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "create a vm")

    @Argument(help: "vm name")
    var name: String

    @Option(help: ArgumentHelp("create a linux or macOS vm"), completion: .list(["linux", "macOS"]))
    var os: OSOption = .linux

    @Option(help: ArgumentHelp("disk size in gb"))
    var diskSize: Int = 50

    func validate() throws {
        if Home.shared.vmDir(name).initialized {
            throw ValidationError("vm already exists, name=\(name)")
        }
    }

    func run() async throws {
        let tempDir = try Home.shared.createTempVMDirectory()

        Logger.info("create nvram.bin")
        _ = try VZEFIVariableStore(creatingVariableStoreAt: tempDir.nvramURL)

        Logger.info("create image.bin, size=\(diskSize)G")
        try tempDir.resizeDisk(diskSize)

        Logger.info("create config.json")
        var config = VMConfig()

        switch os {
        case .linux:
            config.os = .linux
            config.memorySizeInGB(4)
        case .macOS:
            config.os = .macOS
            config.memorySizeInGB(8)
        }
        config.macAddress = VZMACAddress.randomLocallyAdministered().string

        try tempDir.saveConfig(config: config)

        let vmDir = Home.shared.vmDir(name)
        try File.move(tempDir.dir, vmDir.dir)
    }
}
