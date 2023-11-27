import ArgumentParser
import Foundation
import Virtualization

struct Create: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "create vm")

    @Argument(help: "vm name")
    var name: String

    @Option(help: ArgumentHelp("create a linux or macOS vm"), completion: .list(["linux", "macOS"]))
    var os: OS = .linux

    @Option(help: ArgumentHelp("disk size in gb"))
    var diskSize: Int = 50

    @Option(help: "macOS restore image ipsw url, e.g. --ipsw=\"UniversalMac_14.1.1_23B81_Restore.ipsw\"", completion: .file())
    var ipsw: Path?

    func validate() throws {
        if Home.shared.vmDir(name).initialized() {
            throw ValidationError("vm already exists, name=\(name)")
        }
        if os == .macOS && ipsw == nil {
            throw ValidationError("ipsw must not be null for macOS vm")
        }
    }

    func run() async throws {
        let tempDir = try Home.shared.createTempVMDirectory()
        Logger.info("create image.bin, size=\(diskSize)G")
        try tempDir.resizeDisk(UInt64(diskSize) * 1_000_000_000)

        switch os {
        case .linux:
            try createLinuxVM(tempDir)
        case .macOS:
            try await createMacOSVM(tempDir)
        }

        let vmDir = Home.shared.vmDir(name)
        Logger.info("move vm dir, from=\(tempDir.dir), to=\(vmDir.dir)")
        try FileManager.default.moveItem(at: tempDir.dir.url, to: vmDir.dir.url)

        Logger.info("vm created, name=\(name), config=\(vmDir.configPath)")
    }

    private func createLinuxVM(_ tempDir: VMDirectory) throws {
        Logger.info("create nvram.bin")
        _ = try VZEFIVariableStore(creatingVariableStoreAt: tempDir.nvramPath.url)

        Logger.info("create config.json")
        var config = VMConfig()
        config.os = .linux
        config.memory = 1 * 1024 * 1024 * 1024
        config.macAddress = VZMACAddress.randomLocallyAdministered().string
        config.rosetta = false
        try tempDir.saveConfig(config)
    }

    private func createMacOSVM(_ dir: VMDirectory) async throws {
        let image = try await withCheckedThrowingContinuation { continuation in
            VZMacOSRestoreImage.load(from: ipsw!.url) { result in
                continuation.resume(with: result)
            }
        }
        guard let requirements = image.mostFeaturefulSupportedConfiguration else {
            Logger.error("restore image is not supported by current host")
            throw ExitCode.failure
        }

        Logger.info("create nvram.bin")
        _ = try VZMacAuxiliaryStorage(creatingStorageAt: dir.nvramPath.url, hardwareModel: requirements.hardwareModel)

        Logger.info("create config.json")
        var config = VMConfig()
        config.os = .macOS
        config.cpu = max(4, requirements.minimumSupportedCPUCount)
        config.memory = max(8 * 1024 * 1024 * 1024, requirements.minimumSupportedMemorySize)
        config.macAddress = VZMACAddress.randomLocallyAdministered().string
        config.hardwareModel = requirements.hardwareModel.dataRepresentation
        config.machineIdentifier = VZMacMachineIdentifier().dataRepresentation
        try dir.saveConfig(config)

        let macOS = MacOS(dir)
        let virtualMachine = try macOS.createVirtualMachine(config)
        try await installMacOS(virtualMachine)
    }

    @MainActor
    private func installMacOS(_ virtualMachine: VZVirtualMachine) async throws {
        var observers: [NSKeyValueObservation] = []  // must hold observer references during installation to print process
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task {
                let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: ipsw!.url)
                Logger.info("instal macOS")
                let observer = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
                    Logger.info("instal progress: \(Int(change.newValue! * 100))%")
                }
                observers.append(observer)
                installer.install { result in
                    if case let .failure(error) = result {
                        fatalError(error.localizedDescription)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        Logger.info("macOS install finished")
    }
}
