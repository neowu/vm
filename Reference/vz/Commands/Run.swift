import ArgumentParser
import Cocoa
import Darwin
import Dispatch
import SwiftUI
import Virtualization

var vm: VM?

struct Run: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Run a VM")

  @Argument(help: "VM name")
  var name: String

  @Flag(help: "open a UI window.")
  var gui: Bool = false

  @Flag(help: "Boot into recovery mode")
  var recovery: Bool = false

  @Option(help: ArgumentHelp("""
  Additional disk attachments with an optional read-only specifier\n(e.g. --disk=\"disk.bin\" --disk=\"ubuntu.iso:ro\" --disk=\"/dev/disk0\")
  """, discussion: """
  Can be either a disk image file or a block device like a local SSD on AWS EC2 Mac instances.

  Learn how to create a disk image using Disk Utility here:
  https://support.apple.com/en-gb/guide/disk-utility/dskutl11888/mac

  To work with block devices 'tart' binary must be executed as root which affects locating Tart VMs.
  To workaround this issue pass TART_HOME explicitly:

  sudo TART_HOME="$HOME/.tart" tart run sonoma --disk=/dev/disk0
  """, valueName: "path[:ro]"))
  var disk: [String] = []

  @Option(name: [.customLong("rosetta")], help: ArgumentHelp(
    "Attaches a Rosetta share to the guest Linux VM with a specific tag (e.g. --rosetta=\"rosetta\")",
    discussion: """
    Requires host to be macOS 13.0 (Ventura) with Rosetta installed. The latter can be done
    by running "softwareupdate --install-rosetta" (without quotes) in the Terminal.app.

    Note that you also have to configure Rosetta in the guest Linux VM by following the
    steps from "Mount the Shared Directory and Register Rosetta" section here:
    https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#3978496
    """,
    valueName: "tag"
  ))
  var rosettaTag: String?

  @Option(help: ArgumentHelp("""
  Additional directory shares with an optional read-only specifier\n(e.g. --dir=\"~/src/build\" or --dir=\"~/src/sources:ro\")
  """, discussion: """
  Requires host to be macOS 13.0 (Ventura) or newer.
  A shared directory is automatically mounted to "/Volumes/My Shared Files" directory on macOS,
  while on Linux you have to do it manually: "mount -t virtiofs com.apple.virtio-fs.automount /mount/point".
  For macOS guests, they must be running macOS 13.0 (Ventura) or newer.

  In case of passing multiple directories it is required to prefix them with names e.g. --dir=\"build:~/src/build\" --dir=\"sources:~/src/sources:ro\"
  These names will be used as directory names under the mounting point inside guests. For the example above it will be
  "/Volumes/My Shared Files/build" and "/Volumes/My Shared Files/sources" respectively.
  """, valueName: "[name:]path[:ro]"))
  var dir: [String] = []

  @Flag(help: ArgumentHelp("Whether system hot keys should be sent to the guest instead of the host",
    discussion: "If enabled then system hot keys like Cmd+Tab will be sent to the guest instead of the host."))
  var captureSystemKeys: Bool = false

  mutating func validate() throws {
    if !gui && captureSystemKeys {
      throw ValidationError("--captures-system-keys can only be used with the default VM view")
    }
  }

  @MainActor
  func run() async throws {
    let localStorage = VMStorageLocal()
    let vmDir = try localStorage.open(name)

    let storageLock = try FileLock(lockURL: Config().tartHomeDir)

    let additionalDiskAttachments = try additionalDiskAttachments()

    vm = try VM(
      vmDir: vmDir,      
      additionalStorageDevices: additionalDiskAttachments,
      directorySharingDevices: directoryShares() + rosettaDirectoryShare()   
    )

    // Lock the VM
    //
    // More specifically, lock the "config.json", because we can't lock
    // directories with fcntl(2)-based locking and we better not interfere
    // with the VM's disk and NVRAM, because they are opened (and even seem
    // to be locked) directly by the Virtualization.Framework's process.
    //
    // Note that due to "completely stupid semantics"[1] of the fcntl-based
    // file locking, we need to acquire the lock after we read the VM's
    // configuration file, otherwise we will loose the lock.
    //
    // [1]: https://man.openbsd.org/fcntl
    let lock = try PIDLock(lockURL: vmDir.configURL)
    if try !lock.trylock() {
      throw RuntimeError.VMAlreadyRunning("VM \"\(name)\" is already running!")
    }

    // now VM state will return "running" so we can unlock
    try storageLock.unlock()

    let task = Task {        
      vm!.start(recovery: recovery)
    }

    // handle ctrl+c or stop
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)    
    sigintSrc.setEventHandler {
      task.cancel()
      Task {
        try vm!.stop()     
      }
    }
    sigintSrc.activate()  

    if !gui {
      // enter the main even loop, without bringing up any UI,
      // and just wait for the VM to exit.
      let nsApp = NSApplication.shared
      nsApp.setActivationPolicy(.prohibited)
      nsApp.run()
    } else {
      runUI(captureSystemKeys)
    }
  }

  private func createSerialPortConfiguration(_ tty_read: FileHandle, _ tty_write: FileHandle) -> VZVirtioConsoleDeviceSerialPortConfiguration {
    let serialPortConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()
    let serialPortAttachment = VZFileHandleSerialPortAttachment(
      fileHandleForReading: tty_read,
      fileHandleForWriting: tty_write)

    serialPortConfiguration.attachment = serialPortAttachment
    return serialPortConfiguration
  }

  func isInteractiveSession() -> Bool {
    isatty(STDOUT_FILENO) == 1
  }

  func additionalDiskAttachments() throws -> [VZStorageDeviceConfiguration] {
    var result: [VZStorageDeviceConfiguration] = []
    let readOnlySuffix = ":ro"
    let expandedDiskPaths = disk.map { NSString(string:$0).expandingTildeInPath }

    for rawDisk in expandedDiskPaths {
      let diskReadOnly = rawDisk.hasSuffix(readOnlySuffix)
      let diskPath = diskReadOnly ? String(rawDisk.prefix(rawDisk.count - readOnlySuffix.count)) : rawDisk
      let diskURL = URL(fileURLWithPath: diskPath)

      // check if `diskPath` is a block device or a directory
      if pathHasMode(diskPath, mode: S_IFBLK) || pathHasMode(diskPath, mode: S_IFDIR) {
        print("Using block device\n")
        guard #available(macOS 14, *) else {
          throw UnsupportedOSError("attaching block devices", "are")
        }
        let fileHandle = FileHandle(forUpdatingAtPath: diskPath)
        guard fileHandle != nil else {
          if ProcessInfo.processInfo.userName != "root" {
            throw RuntimeError.VMConfigurationError("need to run as root to work with block devices")
          }
          throw RuntimeError.VMConfigurationError("block device \(diskURL.path) seems to be already in use, unmount it first via 'diskutil unmount'")
        }
        let attachment = try VZDiskBlockDeviceStorageDeviceAttachment(fileHandle: fileHandle!, readOnly: diskReadOnly, synchronizationMode: .full)
        result.append(VZVirtioBlockDeviceConfiguration(attachment: attachment))
      } else {
        // Error out if the disk is locked by the host (e.g. it was mounted in Finder),
        // see https://github.com/cirruslabs/tart/issues/323 for more details.
        if try !diskReadOnly && !FileLock(lockURL: diskURL).trylock() {
          throw RuntimeError.DiskAlreadyInUse("disk \(diskURL.path) seems to be already in use, unmount it first in Finder")
        }

        let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(
          url: diskURL,
          readOnly: diskReadOnly,
          cachingMode: VZDiskImageCachingMode.automatic,
          synchronizationMode: VZDiskImageSynchronizationMode.fsync
        )
        result.append(VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment))
      }
    }

    return result
  }

  func directoryShares() throws -> [VZDirectorySharingDeviceConfiguration] {
    if dir.isEmpty {
      return []
    }

    var directoryShares: [DirectoryShare] = []

    var allNamedShares = true
    for rawDir in dir {
      let directoryShare = try DirectoryShare(parseFrom: rawDir)
      if (directoryShare.name == nil) {
        allNamedShares = false
      }
      directoryShares.append(directoryShare)
    }


    let automountTag = VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag
    let sharingDevice = VZVirtioFileSystemDeviceConfiguration(tag: automountTag)
    if allNamedShares {
      var directories: [String : VZSharedDirectory] = Dictionary()
      try directoryShares.forEach { directories[$0.name!] = try $0.createConfiguration() }
      sharingDevice.share = VZMultipleDirectoryShare(directories: directories)
    } else if dir.count > 1 {
      throw ValidationError("invalid --dir syntax: for multiple directory shares each one of them should be named")
    } else if dir.count == 1 {
      let directoryShare = directoryShares.first!
      let singleDirectoryShare = VZSingleDirectoryShare(directory: try directoryShare.createConfiguration())
      sharingDevice.share = singleDirectoryShare
    }

    return [sharingDevice]
  }

  private func rosettaDirectoryShare() throws -> [VZDirectorySharingDeviceConfiguration] {
    guard let rosettaTag = rosettaTag else {
      return []
    }

    switch VZLinuxRosettaDirectoryShare.availability {
    case .notInstalled:
      throw UnsupportedOSError("Rosetta directory share", "is", "that have Rosetta installed")
    case .notSupported:
      throw UnsupportedOSError("Rosetta directory share", "is", "running Apple silicon")
    default:
      break
    }

    try VZVirtioFileSystemDeviceConfiguration.validateTag(rosettaTag)
    let device = VZVirtioFileSystemDeviceConfiguration(tag: rosettaTag)
    device.share = try VZLinuxRosettaDirectoryShare()
    return [device]
  }

  private func runUI(_ captureSystemKeys: Bool) {
    let nsApp = NSApplication.shared
    nsApp.setActivationPolicy(.regular)
    nsApp.activate(ignoringOtherApps: true)

    // nsApp.applicationIconImage = NSImage(data: AppIconData)

    struct MainApp: App {
      static var capturesSystemKeys: Bool = false

      var body: some Scene {
        WindowGroup(vm!.name) {
          Group {
            VMView(vm: vm!, capturesSystemKeys: MainApp.capturesSystemKeys)
            .onAppear {
              NSWindow.allowsAutomaticWindowTabbing = false              
            }
          }.frame(
            minWidth: CGFloat(vm!.config.display.width/2),
            idealWidth: CGFloat(vm!.config.display.width),
            maxWidth: .infinity,
            minHeight: CGFloat(vm!.config.display.height/2),
            idealHeight: CGFloat(vm!.config.display.height),
            maxHeight: .infinity
          )
        }
      }
    }

    NSMenu.setMenuBarVisible(false)
    MainApp.capturesSystemKeys = captureSystemKeys
    MainApp.main()
  }
}

struct VMView: NSViewRepresentable {
  typealias NSViewType = VZVirtualMachineView

  @ObservedObject var vm: VM
  var capturesSystemKeys: Bool

  func makeNSView(context: Context) -> NSViewType {
    let machineView = VZVirtualMachineView()
    machineView.capturesSystemKeys = capturesSystemKeys        
    machineView.automaticallyReconfiguresDisplay = false
    return machineView
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    nsView.virtualMachine = vm.virtualMachine
  }
}

struct DirectoryShare {
  let name: String?
  let path: URL
  let readOnly: Bool

  init(parseFrom: String) throws {
    let readOnlySuffix = ":ro"
    readOnly = parseFrom.hasSuffix(readOnlySuffix)
    let maybeNameAndURL = readOnly ? String(parseFrom.dropLast(readOnlySuffix.count)) : parseFrom

    let splits = maybeNameAndURL.split(separator: ":", maxSplits: 1)

    if splits.count == 2 {
      name = String(splits[0])
      path = URL(fileURLWithPath: NSString(string: String(splits[1])).expandingTildeInPath)
    } else {
      name = nil
      path = URL(fileURLWithPath: NSString(string: String(splits[0])).expandingTildeInPath)
    }
  }

  func createConfiguration() throws -> VZSharedDirectory {
    if !path.isFileURL {
      throw ValidationError("path must be file, path=\(path)")
    }
    return VZSharedDirectory(url: path, readOnly: readOnly)    
  }
}

func pathHasMode(_ path: String, mode: mode_t) -> Bool {
  var st = stat()
  let statRes = stat(path, &st)
  guard statRes != -1 else {
    return false
  }
  return (Int32(st.st_mode) & Int32(mode)) == Int32(mode)
}