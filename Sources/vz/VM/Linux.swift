import Virtualization

struct Linux {
    let dir: VMDirectory
    var gui: Bool = false
    var mount: String?

    init(_ dir: VMDirectory) {
        self.dir = dir
    }

    func createVirtualMachine(_ config: VMConfig, _ rosetta: Bool) throws -> VZVirtualMachine {
        Logger.info("create linux vm, name=\(dir.name)")
        let vzConfig = try createVZVirtualMachineConfiguration(config, rosetta)
        try vzConfig.validate()
        return VZVirtualMachine(configuration: vzConfig)
    }

    func createVZVirtualMachineConfiguration(_ config: VMConfig, _ rosetta: Bool) throws -> VZVirtualMachineConfiguration {
        let vzConfig = VZVirtualMachineConfiguration()

        vzConfig.bootLoader = createBootLoader()

        vzConfig.cpuCount = config.cpu
        vzConfig.memorySize = config.memory

        vzConfig.platform = VZGenericPlatformConfiguration()

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

    private func createBootLoader() -> VZBootLoader {
        // if dir.hasLinuxKernel() {
        //     Logger.info("use linux kernel boot loader")
        //     let bootLoader = VZLinuxBootLoader(kernelURL: dir.vmlinuzURL)
        //     bootLoader.initialRamdiskURL = dir.initrdURL
        //     bootLoader.commandLine = "root=/dev/vda2 ro"
        //     return bootLoader
        // }

        let loader = VZEFIBootLoader()
        loader.variableStore = VZEFIVariableStore(url: dir.nvramURL)
        return loader
    }
}
