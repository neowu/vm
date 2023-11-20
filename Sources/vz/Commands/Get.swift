import ArgumentParser
import Foundation
import Virtualization

struct Get: ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "get vm config")

  @Argument(help: "vm name")
  var name: String

  func validate() throws {
    if !File.exists(Home.shared.vmDir(name).configURL) {
      throw ValidationError("vm not found, name=\(name)")
    }
  }

  func run() throws {
    let vmDir = Home.shared.vmDir(name)
    let config = try vmDir.config()
    print(
      """
      \("name".padding(8))\("os".padding(8))\("cpu".padding(8))\("memory".padding(8))\("status".padding(8))
      """)
    let memorySize = String(format: "%.2fG", config.memorySizeInGB())
    let lock = FileLock(vmDir.configURL)!
    let status = if lock.pid() == nil { "stopped" } else { "running" }
    print(
      """
      \(name.padding(8))\(config.os.rawValue.padding(8))\(String(config.cpuCount).padding(8))\(memorySize.padding(8))\(status.padding(8))
      """)
  }
}
