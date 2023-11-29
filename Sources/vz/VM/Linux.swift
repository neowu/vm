import Virtualization

struct Linux {
    let dir: VMDirectory
    let config: VMConfig
    var gui: Bool = false
    var mount: Path?

    init(_ dir: VMDirectory, _ config: VMConfig) {
        self.dir = dir
        self.config = config
    }

    func createVirtualMachine() throws -> VZVirtualMachine {
        Logger.info("create linux vm, name=\(dir.name)")
        let vzConfig = try createVirtualMachineConfiguration()
        try vzConfig.validate()
        return VZVirtualMachine(configuration: vzConfig)
    }

    func createVirtualMachineConfiguration() throws -> VZVirtualMachineConfiguration {
        let vzConfig = VZVirtualMachineConfiguration()
        vzConfig.cpuCount = config.cpu
        vzConfig.memorySize = config.memory

        vzConfig.bootLoader = bootLoader()
        vzConfig.platform = VZGenericPlatformConfiguration()

        if gui {
            vzConfig.graphicsDevices = [display()]
            vzConfig.keyboards = [VZUSBKeyboardConfiguration()]
            vzConfig.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        }

        vzConfig.networkDevices = [config.network()]
        vzConfig.storageDevices = try storage()

        vzConfig.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
        vzConfig.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

        var sharing: [VZVirtioFileSystemDeviceConfiguration] = []
        if let directories = config.sharingDirectories() {
            sharing += [directories]
        }
        if let rosetta = config.rosetta, rosetta {
            let device = VZVirtioFileSystemDeviceConfiguration(tag: "rosetta")
            device.share = try VZLinuxRosettaDirectoryShare()
            sharing += [device]
        }
        vzConfig.directorySharingDevices = sharing

        return vzConfig
    }

    private func bootLoader() -> VZBootLoader {
        let loader = VZEFIBootLoader()
        loader.variableStore = VZEFIVariableStore(url: dir.nvramPath.url)
        return loader
    }

    private func display() -> VZGraphicsDeviceConfiguration {
        let (width, height) = config.displayPixels
        let display = VZVirtioGraphicsDeviceConfiguration()
        display.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: width, heightInPixels: height)
        ]
        return display
    }

    private func storage() throws -> [VZStorageDeviceConfiguration] {
        let disk = VZVirtioBlockDeviceConfiguration(
            attachment: try VZDiskImageStorageDeviceAttachment(
                url: dir.diskPath.url,
                readOnly: false,
                cachingMode: VZDiskImageCachingMode.automatic,
                synchronizationMode: VZDiskImageSynchronizationMode.fsync))

        var storage: [VZStorageDeviceConfiguration] = [disk]
        if let mount = mount {
            storage.append(
                VZUSBMassStorageDeviceConfiguration(
                    attachment: try VZDiskImageStorageDeviceAttachment(url: mount.url, readOnly: true)))
        }
        return storage
    }
}
