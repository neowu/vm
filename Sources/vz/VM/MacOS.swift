import Virtualization

struct MacOS {
    let dir: VMDirectory
    let config: VMConfig

    init(_ dir: VMDirectory, _ config: VMConfig) {
        self.dir = dir
        self.config = config
    }

    func createVirtualMachine() throws -> VZVirtualMachine {
        Logger.info("create macOS vm, name=\(dir.name)")
        let vzConfig = try createVirtualMachineConfiguration()
        try vzConfig.validate()
        return VZVirtualMachine(configuration: vzConfig)
    }

    private func createVirtualMachineConfiguration() throws -> VZVirtualMachineConfiguration {
        let vzConfig = VZVirtualMachineConfiguration()
        vzConfig.cpuCount = config.cpu
        vzConfig.memorySize = config.memory

        vzConfig.bootLoader = VZMacOSBootLoader()
        vzConfig.platform = platform()

        vzConfig.graphicsDevices = [display()]
        vzConfig.keyboards = [VZMacKeyboardConfiguration()]
        vzConfig.pointingDevices = [VZMacTrackpadConfiguration()]

        vzConfig.storageDevices = [try disk()]
        vzConfig.networkDevices = [config.network()]

        vzConfig.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
        vzConfig.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

        if let directories = config.sharingDirectories() {
            vzConfig.directorySharingDevices = [directories]
        }

        return vzConfig
    }

    private func platform() -> VZPlatformConfiguration {
        let platform = VZMacPlatformConfiguration()
        platform.auxiliaryStorage = VZMacAuxiliaryStorage(url: dir.nvramPath.url)
        platform.hardwareModel = VZMacHardwareModel(dataRepresentation: config.hardwareModel!)!
        platform.machineIdentifier = VZMacMachineIdentifier(dataRepresentation: config.machineIdentifier!)!
        return platform
    }

    private func display() -> VZGraphicsDeviceConfiguration {
        let (width, height) = config.displayPixels
        let display = VZMacGraphicsDeviceConfiguration()
        display.displays = [
            VZMacGraphicsDisplayConfiguration(for: NSScreen.main!, sizeInPoints: NSSize(width: width, height: height))
        ]
        return display
    }

    private func disk() throws -> VZStorageDeviceConfiguration {
        return VZVirtioBlockDeviceConfiguration(
            attachment: try VZDiskImageStorageDeviceAttachment(
                url: dir.diskPath.url,
                readOnly: false,
                cachingMode: VZDiskImageCachingMode.automatic,
                synchronizationMode: VZDiskImageSynchronizationMode.fsync))
    }
}
