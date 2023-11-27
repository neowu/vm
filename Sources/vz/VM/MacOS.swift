import Virtualization

struct MacOS {
    let dir: VMDirectory
    var mount: Path?

    init(_ dir: VMDirectory) {
        self.dir = dir
    }

    func createVirtualMachine(_ config: VMConfig) throws -> VZVirtualMachine {
        Logger.info("create macOS vm, name=\(dir.name)")
        let vzConfig = try createVirtualMachineConfiguration(config)
        try vzConfig.validate()
        return VZVirtualMachine(configuration: vzConfig)
    }

    func createVirtualMachineConfiguration(_ config: VMConfig) throws -> VZVirtualMachineConfiguration {
        let vzConfig = VZVirtualMachineConfiguration()
        vzConfig.cpuCount = config.cpu
        vzConfig.memorySize = config.memory

        vzConfig.bootLoader = VZMacOSBootLoader()

        let platform = VZMacPlatformConfiguration()
        platform.auxiliaryStorage = VZMacAuxiliaryStorage(url: dir.nvramPath.url)
        platform.hardwareModel = VZMacHardwareModel(dataRepresentation: config.hardwareModel!)!
        platform.machineIdentifier = VZMacMachineIdentifier(dataRepresentation: config.machineIdentifier!)!
        vzConfig.platform = platform

        vzConfig.graphicsDevices = [config.graphics()]
        vzConfig.keyboards = [VZUSBKeyboardConfiguration()]
        vzConfig.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]

        vzConfig.networkDevices = [config.network()]

        var storage: [VZStorageDeviceConfiguration] = [
            VZVirtioBlockDeviceConfiguration(
                attachment: try VZDiskImageStorageDeviceAttachment(
                    url: dir.diskPath.url,
                    readOnly: false,
                    cachingMode: VZDiskImageCachingMode.automatic,
                    synchronizationMode: VZDiskImageSynchronizationMode.fsync))
        ]
        if let mount = mount {
            storage.append(
                VZUSBMassStorageDeviceConfiguration(
                    attachment: try VZDiskImageStorageDeviceAttachment(url: mount.url, readOnly: true)))
        }
        vzConfig.storageDevices = storage

        vzConfig.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
        vzConfig.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

        if let directories = config.sharingDirectories() {
            vzConfig.directorySharingDevices = [directories]
        }

        return vzConfig
    }
}
