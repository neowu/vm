import Foundation
import Virtualization

enum OS: String, Codable {
  case linux, macOS
}

struct VMConfig: Codable {
  var os: OS = .linux
  var cpuCount: Int = 4
  var memorySize: UInt64 = 4 * 1024 * 1024 * 1024
  var macAddress: String?
  var display: String?
  var sharing: [String: String] = [:]

  mutating func memorySizeInGB(_ size: Int) {
    memorySize = UInt64(size) * 1024 * 1024 * 1024
  }

  func memorySizeInGB() -> Float {
    return Float(memorySize) / (1024 * 1024 * 1024)
  }

  func displayInPixels() -> (Int, Int) {
    let pixels = display!.components(separatedBy: "x")
    return (Int(pixels[0])!, Int(pixels[1])!)
  }

  func network() -> VZVirtioNetworkDeviceConfiguration {
    let network = VZVirtioNetworkDeviceConfiguration()
    network.attachment = VZNATNetworkDeviceAttachment()
    network.macAddress = VZMACAddress(string: macAddress!)!
    return network
  }

  func sharingDirectories() -> [String: VZSharedDirectory] {
    return sharing.mapValues({ value in
      return VZSharedDirectory(url: value.toFileURL(), readOnly: false)
    })
  }
}
