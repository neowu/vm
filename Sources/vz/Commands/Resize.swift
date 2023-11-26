import ArgumentParser
import Virtualization

struct Resize: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "increase disk image size")

    @Argument(help: "vm name", completion: .custom(completeVMName))
    var name: String

    @Option(help: ArgumentHelp("disk size in gb"))
    var diskSize: Int = 50

    func validate() throws {
        let vmDir = Home.shared.vmDir(name)
        if !vmDir.initialized() {
            throw ValidationError("vm not initialized, name=\(name)")
        }
        let file = try vmDir.diskURL.resourceValues(forKeys: [.totalFileSizeKey])
        let currentSize = file.totalFileSize!
        if currentSize >= diskSize * 1_000_000_000 {
            throw ValidationError("disk size must larger than current, current=\(currentSize)")
        }
    }

    func run() throws {
        let vmDir = Home.shared.vmDir(name)
        Logger.info("resize image.bin, size=\(diskSize)G")
        try vmDir.resizeDisk(UInt64(diskSize) * 1_000_000_000)
    }
}
