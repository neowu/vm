import Foundation
import Virtualization

enum OS: String, Codable {
    case linux, macOS
}

struct VMConfig: Codable {
    var os: OS = .linux
    var cpu: Int = 4
    var memory: UInt64 = 4 * 1024 * 1024 * 1024
    var macAddress: String?
    var display: String = "1024x768"
    var sharing: [String: String] = [:]

    mutating func memorySizeInGB(_ size: Int) {
        memory = UInt64(size) * 1024 * 1024 * 1024
    }

    func memorySizeInGB() -> Float {
        return Float(memory) / (1024 * 1024 * 1024)
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

    func graphics() -> VZVirtioGraphicsDeviceConfiguration {
        let graphics = VZVirtioGraphicsDeviceConfiguration()
        let pixels = display.components(separatedBy: "x")
        graphics.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: Int(pixels[0])!, heightInPixels: Int(pixels[1])!)
        ]
        return graphics
    }
}
