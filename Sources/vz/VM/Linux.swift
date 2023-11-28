import Virtualization

struct Linux {
    let dir: VMDirectory
    var gui: Bool = false
    var mount: Path?

    init(_ dir: VMDirectory) {
        self.dir = dir
    }

    func createVirtualMachine(_ config: VMConfig) throws -> VZVirtualMachine {
        Logger.info("create linux vm, name=\(dir.name)")
        let vzConfig = try createVirtualMachineConfiguration(config)
        try vzConfig.validate()
        return VZVirtualMachine(configuration: vzConfig)
    }

    func createVirtualMachineConfiguration(_ config: VMConfig) throws -> VZVirtualMachineConfiguration {
        let vzConfig = VZVirtualMachineConfiguration()
        vzConfig.cpuCount = config.cpu
        vzConfig.memorySize = config.memory
        vzConfig.bootLoader = createBootLoader()

        vzConfig.platform = VZGenericPlatformConfiguration()

        if gui {
            let (width, height) = config.displayPixels
            let display = VZVirtioGraphicsDeviceConfiguration()
            display.scanouts = [
                VZVirtioGraphicsScanoutConfiguration(widthInPixels: width, heightInPixels: height)
            ]
            vzConfig.graphicsDevices = [display]
            vzConfig.keyboards = [VZUSBKeyboardConfiguration()]
            vzConfig.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        }

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

    private func createBootLoader() -> VZBootLoader {
        let loader = VZEFIBootLoader()
        loader.variableStore = VZEFIVariableStore(url: dir.nvramPath.url)
        return loader
    }
}
