import Virtualization

struct Linux {
    let dir: VMDirectory
    var gui: Bool = false
    var mount: String?

    init(_ dir: VMDirectory) {
        self.dir = dir
    }

    func createVirtualMachine(_ config: VMConfig, _ rosetta: Bool) throws -> VZVirtualMachine {
        Logger.info("create vm")
        let vzConfig = try createVZVirtualMachineConfiguration(config, rosetta)
        try vzConfig.validate()
        return VZVirtualMachine(configuration: vzConfig)
    }

    func createVZVirtualMachineConfiguration(_ config: VMConfig, _ rosetta: Bool) throws -> VZVirtualMachineConfiguration {
        let vzConfig = VZVirtualMachineConfiguration()

        let loader = VZEFIBootLoader()
        loader.variableStore = VZEFIVariableStore(url: dir.nvramURL)
        vzConfig.bootLoader = loader

        vzConfig.cpuCount = config.cpu
        vzConfig.memorySize = config.memory

        if gui {
            vzConfig.graphicsDevices = [config.graphics()]
            vzConfig.keyboards = [VZUSBKeyboardConfiguration()]
            vzConfig.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        }

        vzConfig.networkDevices = [config.network()]

        var storage: [VZStorageDeviceConfiguration] = [
            VZVirtioBlockDeviceConfiguration(
                attachment: try VZDiskImageStorageDeviceAttachment(
                    url: dir.diskURL,
                    readOnly: false,
                    cachingMode: VZDiskImageCachingMode.automatic,
                    synchronizationMode: VZDiskImageSynchronizationMode.fsync))
        ]
        if let mount = mount {
            storage.append(
                VZUSBMassStorageDeviceConfiguration(
                    attachment: try VZDiskImageStorageDeviceAttachment(url: mount.toFileURL(), readOnly: true)))
        }
        vzConfig.storageDevices = storage

        vzConfig.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

        var sharing: [VZVirtioFileSystemDeviceConfiguration] = []
        let directories = config.sharingDirectories()
        if !directories.isEmpty {
            let device = VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)
            device.share = VZMultipleDirectoryShare(directories: directories)
            sharing += [device]
        }
        if rosetta {
            let device = VZVirtioFileSystemDeviceConfiguration(tag: "rosetta")
            device.share = try VZLinuxRosettaDirectoryShare()
            sharing += [device]
        }
        vzConfig.directorySharingDevices = sharing

        return vzConfig
    }
}
