import ArgumentParser
import Dispatch
import SwiftUI
import Foundation

struct Create: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Create a VM")

  @Argument(help: "VM name")
  var name: String

  @Option(help: ArgumentHelp("create a macOS VM ipsw file", valueName: "path"))
  var fromIPSW: String?

  @Flag(help: "create a Linux VM")
  var linux: Bool = false

  @Option(help: ArgumentHelp("Disk size in Gb")) 
  var diskSize: UInt16 = 50

  func validate() throws {
    if fromIPSW != nil && !FileManager.default.fileExists(atPath: fromIPSW!) {
      throw ValidationError("ipsw path doesn't exist, path=\(fromIPSW!)")
    }

    if fromIPSW == nil && !linux {
      throw ValidationError("Please specify either a --from-ipsw or --linux option!")
    }
  }

  func run() async throws {
    let tmpVMDir = try VMDirectory.temporary()

    // Lock the temporary VM directory to prevent it's garbage collection
    let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
    try tmpVMDirLock.lock()

    try await withTaskCancellationHandler(operation: {
      if let fromIPSW = fromIPSW {
        let ipswURL = URL(fileURLWithPath: fromIPSW)      
        _ = try await VM(vmDir: tmpVMDir, ipswURL: ipswURL, diskSizeGB: diskSize)
      }

      if linux {
        _ = try await VM.linux(vmDir: tmpVMDir, diskSizeGB: diskSize)
      }

      try VMStorageLocal().move(name, from: tmpVMDir)
    }, onCancel: {
      try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
    })
  }
}
