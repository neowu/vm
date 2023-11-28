import ArgumentParser
import Foundation
import Virtualization

enum OS: String, Codable, ExpressibleByArgument {
    case linux, macOS
}

struct VMConfig: Codable {
    var os: OS = .linux
    var cpu: Int = 2
    var memory: UInt64 = 1 * 1024 * 1024 * 1024
    var macAddress: String?
    var display: String = "1024x768"
    var sharing: [String: String] = [:]

    // used by linux
    // refer to https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#3978496
    var rosetta: Bool?

    // used by macOS
    var machineIdentifier: Data?
    var hardwareModel: Data?

    var displayPixels: (Int, Int) {
        let pixels = display.components(separatedBy: "x")
        return (Int(pixels[0])!, Int(pixels[1])!)
    }

    func network() -> VZVirtioNetworkDeviceConfiguration {
        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        network.macAddress = VZMACAddress(string: macAddress!)!
        return network
    }

    func sharingDirectories() -> VZVirtioFileSystemDeviceConfiguration? {
        if sharing.isEmpty {
            return nil
        }
        let directories = sharing.mapValues({ value in
            return VZSharedDirectory(url: Path(value).url, readOnly: false)
        })
        let device = VZVirtioFileSystemDeviceConfiguration(tag: VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag)
        device.share = VZMultipleDirectoryShare(directories: directories)
        return device
    }
}
