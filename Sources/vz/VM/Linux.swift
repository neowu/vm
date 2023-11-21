import Virtualization

struct Linux {
  let dir: VMDirectory
  var gui: Bool = false
  var disk: String?

  init(_ dir: VMDirectory) {
    self.dir = dir
  }

  func createVirtualMachine() throws -> VZVirtualMachine {
    Logger.info("create vm configuration")
    let config = try createVZVirtualMachineConfiguration()
    try config.validate()
    return VZVirtualMachine(configuration: config)
  }

  func createVZVirtualMachineConfiguration() throws -> VZVirtualMachineConfiguration {
    let config = try dir.config()

    let configuration = VZVirtualMachineConfiguration()

    let loader = VZEFIBootLoader()
    loader.variableStore = VZEFIVariableStore(url: dir.nvramURL)
    configuration.bootLoader = loader

    configuration.cpuCount = config.cpuCount
    configuration.memorySize = config.memorySize

    if gui {
      configuration.graphicsDevices = [config.graphics()]
      configuration.keyboards = [VZUSBKeyboardConfiguration()]
      configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
    }

    configuration.networkDevices = [config.network()]

    var storage: [VZStorageDeviceConfiguration] = [
      VZVirtioBlockDeviceConfiguration(
        attachment: try VZDiskImageStorageDeviceAttachment(
          url: dir.diskURL,
          readOnly: false,
          cachingMode: VZDiskImageCachingMode.automatic,
          synchronizationMode: VZDiskImageSynchronizationMode.fsync))
    ]
    if let disk = disk {
      storage.append(
        VZUSBMassStorageDeviceConfiguration(
          attachment: try VZDiskImageStorageDeviceAttachment(
            url: disk.toFileURL(),
            readOnly: true)))
    }
    configuration.storageDevices = storage

    configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

    let directories = config.sharingDirectories()
    if !directories.isEmpty {
      let tag = VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag
      let sharing = VZVirtioFileSystemDeviceConfiguration(tag: tag)
      sharing.share = VZMultipleDirectoryShare(directories: directories)
      configuration.directorySharingDevices = [sharing]
    }

    return configuration
  }
}
