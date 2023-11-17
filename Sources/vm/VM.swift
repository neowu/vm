import Foundation
import Virtualization

struct UnsupportedRestoreImageError: Error {
}

struct NoMainScreenFoundError: Error {
}

struct DownloadFailed: Error {
}

struct UnsupportedOSError: Error, CustomStringConvertible {
  let description: String

  init(_ what: String, _ plural: String, _ requires: String = "running macOS 13.0 (Ventura) or newer") {
    description = "error: \(what) \(plural) only supported on hosts \(requires)"
  }
}

struct UnsupportedArchitectureError: Error {
}

class VM: NSObject, VZVirtualMachineDelegate, ObservableObject {
  // Virtualization.Framework's virtual machine
  @Published var virtualMachine: VZVirtualMachine

  // Virtualization.Framework's virtual machine configuration
  var configuration: VZVirtualMachineConfiguration

  // VM's config
  var name: String

  // VM's config
  var config: VMConfig

  var runTask: Task<Void, Error>?

  init(vmDir: VMDirectory,
       additionalStorageDevices: [VZStorageDeviceConfiguration] = [],
       directorySharingDevices: [VZDirectorySharingDeviceConfiguration] = [],
       serialPorts: [VZSerialPortConfiguration] = []
  ) throws {
    name = vmDir.name
    config = try VMConfig.init(fromURL: vmDir.configURL)

    if config.arch != CurrentArchitecture() {
      throw UnsupportedArchitectureError()
    }

    // Initialize the virtual machine and its configuration    
    configuration = try Self.craftConfiguration(diskURL: vmDir.diskURL,
                                                nvramURL: vmDir.nvramURL, vmConfig: config,
                                                additionalStorageDevices: additionalStorageDevices,
                                                directorySharingDevices: directorySharingDevices,
                                                serialPorts: serialPorts)
    virtualMachine = VZVirtualMachine(configuration: configuration)

    super.init()
    virtualMachine.delegate = self
  }

  var inFinalState: Bool {
    get {
      virtualMachine.state == VZVirtualMachine.State.stopped ||
        virtualMachine.state == VZVirtualMachine.State.paused ||
        virtualMachine.state == VZVirtualMachine.State.error

    }
  }

  init(
    vmDir: VMDirectory,
    ipswURL: URL,
    diskSizeGB: UInt16,    
    additionalStorageDevices: [VZStorageDeviceConfiguration] = [],
    directorySharingDevices: [VZDirectorySharingDeviceConfiguration] = [],
    serialPorts: [VZSerialPortConfiguration] = []
  ) async throws {    
    // Load the restore image and try to get the requirements
    // that match both the image and our platform
    let image = try await withCheckedThrowingContinuation { continuation in
      VZMacOSRestoreImage.load(from: ipswURL) { result in
        continuation.resume(with: result)
      }
    }

    guard let requirements = image.mostFeaturefulSupportedConfiguration else {
      throw UnsupportedRestoreImageError()
    }

    // Create NVRAM
    _ = try VZMacAuxiliaryStorage(creatingStorageAt: vmDir.nvramURL, hardwareModel: requirements.hardwareModel)

    // Create disk
    try vmDir.resizeDisk(diskSizeGB)

    name = vmDir.name
    // Create config
    config = VMConfig(
      platform: Darwin(ecid: VZMacMachineIdentifier(), hardwareModel: requirements.hardwareModel),
      cpuCountMin: requirements.minimumSupportedCPUCount,
      memorySizeMin: requirements.minimumSupportedMemorySize
    )
    // allocate at least 4 CPUs because otherwise VMs are frequently freezing
    try config.setCPU(cpuCount: max(4, requirements.minimumSupportedCPUCount))
    try config.save(toURL: vmDir.configURL)

    // Initialize the virtual machine and its configuration
    configuration = try Self.craftConfiguration(diskURL: vmDir.diskURL, nvramURL: vmDir.nvramURL,
                                                vmConfig: config,
                                                additionalStorageDevices: additionalStorageDevices,
                                                directorySharingDevices: directorySharingDevices,
                                                serialPorts: serialPorts
    )
    virtualMachine = VZVirtualMachine(configuration: configuration)

    super.init()
    virtualMachine.delegate = self

    // Run automated installation
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      DispatchQueue.main.async { [ipswURL] in
        let installer = VZMacOSInstaller(virtualMachine: self.virtualMachine, restoringFromImageAt: ipswURL)

        defaultLogger.appendNewLine("Installing OS...")
        ProgressObserver(installer.progress).log(defaultLogger)

        installer.install { result in
          continuation.resume(with: result)
        }
      }
    }
  }

  @available(macOS 13, *)
  static func linux(vmDir: VMDirectory, diskSizeGB: UInt16) async throws -> VM {
    // Create NVRAM
    _ = try VZEFIVariableStore(creatingVariableStoreAt: vmDir.nvramURL)

    // Create disk
    try vmDir.resizeDisk(diskSizeGB)

    // Create config
    let config = VMConfig(platform: Linux(), cpuCountMin: 4, memorySizeMin: 4096 * 1024 * 1024)
    try config.save(toURL: vmDir.configURL)

    return try VM(vmDir: vmDir)
  }

  func run() async throws {
    if Task.isCancelled {
      try await stop()
    }
  }

  @MainActor
  func start(recovery: Bool) async throws {
    let startOptions = VZMacOSVirtualMachineStartOptions()
    startOptions.startUpFromMacOSRecovery = recovery
    try await virtualMachine.start(options: startOptions)
  }

  @MainActor
  private func resume() async throws {
    try await virtualMachine.resume()
  }

  @MainActor
  private func stop() async throws {
    if self.virtualMachine.canRequestStop {
      print("request VM to stop")
      try self.virtualMachine.requestStop()
    }
    // print("await VM to stop")
    // try await self.virtualMachine.stop()
    // print("VM stopped")
    print("sleep 10s")
    do {
      sleep(10)
    }
    print("end sleep")
  }

  static func craftConfiguration(
    diskURL: URL,
    nvramURL: URL,
    vmConfig: VMConfig,    
    additionalStorageDevices: [VZStorageDeviceConfiguration],
    directorySharingDevices: [VZDirectorySharingDeviceConfiguration],
    serialPorts: [VZSerialPortConfiguration]
  ) throws -> VZVirtualMachineConfiguration {
    let configuration = VZVirtualMachineConfiguration()

    // Boot loader
    configuration.bootLoader = try vmConfig.platform.bootLoader(nvramURL: nvramURL)

    // CPU and memory
    configuration.cpuCount = vmConfig.cpuCount
    configuration.memorySize = vmConfig.memorySize

    // Platform
    configuration.platform = try vmConfig.platform.platform(nvramURL: nvramURL)

    // Display
    configuration.graphicsDevices = [vmConfig.platform.graphicsDevice(vmConfig: vmConfig)]

    // Audio
    // if !suspendable {
    //   let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
    //   let inputAudioStreamConfiguration = VZVirtioSoundDeviceInputStreamConfiguration()
    //   inputAudioStreamConfiguration.source = VZHostAudioInputStreamSource()
    //   let outputAudioStreamConfiguration = VZVirtioSoundDeviceOutputStreamConfiguration()
    //   outputAudioStreamConfiguration.sink = VZHostAudioOutputStreamSink()
    //   soundDeviceConfiguration.streams = [inputAudioStreamConfiguration, outputAudioStreamConfiguration]
    //   configuration.audioDevices = [soundDeviceConfiguration]
    // }

    // Keyboard and mouse
    configuration.keyboards = vmConfig.platform.keyboards()
    configuration.pointingDevices = vmConfig.platform.pointingDevices()
    
    // Networking
    let vio = VZVirtioNetworkDeviceConfiguration()
    vio.attachment = VZNATNetworkDeviceAttachment()
    vio.macAddress = vmConfig.macAddress
    configuration.networkDevices = [vio]

    // Storage
    var devices: [VZStorageDeviceConfiguration] = [
      VZVirtioBlockDeviceConfiguration(attachment: try VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false, cachingMode: VZDiskImageCachingMode.automatic, synchronizationMode: VZDiskImageSynchronizationMode.fsync))
    ]
    devices.append(contentsOf: additionalStorageDevices)
    configuration.storageDevices = devices

    // Entropy
    configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

    // Directory sharing devices
    configuration.directorySharingDevices = directorySharingDevices

    // Serial Port
    configuration.serialPorts = serialPorts

    // Version console device
    //
    // A dummy console device useful for implementing
    // host feature checks in the guest agent software.
    // if !suspendable {
    //   let consolePort = VZVirtioConsolePortConfiguration()
    //   consolePort.name = "tart-version-\(CI.version)"

    //   let consoleDevice = VZVirtioConsoleDeviceConfiguration()
    //   consoleDevice.ports[0] = consolePort

    //   configuration.consoleDevices.append(consoleDevice)
    // }

    try configuration.validate()

    return configuration
  }

  func guestDidStop(_ virtualMachine: VZVirtualMachine) {
    print("guest has stopped the virtual machine")
    runTask!.cancel()
  }

  func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
    print("guest has stopped the virtual machine due to error: \(error)")
    runTask!.cancel()
  }

  func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: Error) {
    print("virtual machine's network attachment \(networkDevice) has been disconnected with error: \(error)")
    runTask!.cancel()
  }
}
