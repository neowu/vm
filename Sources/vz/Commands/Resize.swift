import ArgumentParser
import Virtualization

struct Resize: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "increase disk image size")

    @Argument(help: "vm name", completion: .custom(completeVMName))
    var name: String

    @Option(help: ArgumentHelp("disk size in gb"))
    var diskSize: Int = 50

    func validate() throws {
        let dir = Home.shared.vmDir(name)
        if !dir.initialized() {
            throw ValidationError("vm not initialized, name=\(name)")
        }
        let file = try dir.diskPath.url.resourceValues(forKeys: [.totalFileSizeKey])
        let currentSize = file.totalFileSize!
        if currentSize >= diskSize * 1_000_000_000 {
            throw ValidationError("disk size must larger than current, current=\(currentSize)")
        }
    }

    func run() throws {
        let dir = Home.shared.vmDir(name)
        Logger.info("resize image.bin, size=\(diskSize)G")
        try dir.resizeDisk(UInt64(diskSize) * 1_000_000_000)
    }
}
