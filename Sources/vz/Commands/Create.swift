import ArgumentParser
import Foundation
import Virtualization

struct Create: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "create a vm")

    @Argument(help: "vm name")
    var name: String

    @Option(help: ArgumentHelp("create a linux or macOS vm"), completion: .list(["linux", "macOS"]))
    var os: OS = .linux

    @Option(help: ArgumentHelp("disk size in gb"))
    var diskSize: Int = 50

    func validate() throws {
        if Home.shared.vmDir(name).initialized() {
            throw ValidationError("vm already exists, name=\(name)")
        }
    }

    func run() throws {
        let tempDir = try Home.shared.createTempVMDirectory()

        Logger.info("create nvram.bin")
        _ = try VZEFIVariableStore(creatingVariableStoreAt: tempDir.nvramPath.url)

        Logger.info("create image.bin, size=\(diskSize)G")
        try tempDir.resizeDisk(UInt64(diskSize) * 1_000_000_000)

        Logger.info("create config.json")
        var config = VMConfig()

        switch os {
        case .linux:
            config.os = .linux
            config.memory = 1 * 1024 * 1024 * 1024
        case .macOS:
            config.os = .macOS
            config.memory = 8 * 1024 * 1024 * 1024
        }
        config.macAddress = VZMACAddress.randomLocallyAdministered().string

        try tempDir.saveConfig(config)

        let vmDir = Home.shared.vmDir(name)
        Logger.info("move vm dir, from=\(tempDir.dir), to=\(vmDir.dir)")
        try FileManager.default.moveItem(at: tempDir.dir.url, to: vmDir.dir.url)

        Logger.info("vm created, name=\(name), config=\(vmDir.configPath)")
    }
}
