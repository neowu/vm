import Virtualization

enum CodingKeys: String, CodingKey {  
  case os
  case arch
  case cpuCount
  case memorySize
  case macAddress
  case display

  // macOS-specific keys
  case ecid
  case hardwareModel
}

struct VMDisplayConfig: Codable {
  var width: Int = 1024
  var height: Int = 768
}

extension VMDisplayConfig: CustomStringConvertible {
  var description: String {
    "\(width)x\(height)"
  }
}

struct VMConfig: Codable {
  var os: OS
  var arch: Architecture
  var platform: Platform
  private(set) var cpuCount: Int
  private(set) var memorySize: UInt64
  var macAddress: VZMACAddress
  var display: VMDisplayConfig = VMDisplayConfig()

  init(
    platform: Platform,
    cpuCount: Int,
    memorySize: UInt64,
    macAddress: VZMACAddress = VZMACAddress.randomLocallyAdministered()
  ) {
    self.os = platform.os()
    self.arch = CurrentArchitecture()
    self.platform = platform
    self.macAddress = macAddress
    self.cpuCount = cpuCount
    self.memorySize = memorySize
  }

  init(fromURL: URL) throws {
    self = try Config.jsonDecoder().decode(Self.self, from: try Data(contentsOf: fromURL))
  }

  func save(toURL: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    try encoder.encode(self).write(to: toURL)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    os = try container.decodeIfPresent(OS.self, forKey: .os) ?? .darwin
    arch = try container.decodeIfPresent(Architecture.self, forKey: .arch) ?? .arm64
    switch os {
    case .darwin:
      platform = try Darwin(from: decoder)
    case .linux:
      platform = try Linux(from: decoder)
    }
    cpuCount = try container.decode(Int.self, forKey: .cpuCount)    
    memorySize = try container.decode(UInt64.self, forKey: .memorySize)

    let encodedMacAddress = try container.decode(String.self, forKey: .macAddress)
    guard let macAddress = VZMACAddress.init(string: encodedMacAddress) else {
      throw DecodingError.dataCorruptedError(
        forKey: .hardwareModel,
        in: container,
        debugDescription: "failed to initialize VZMacAddress using the provided value")
    }
    self.macAddress = macAddress

    display = try container.decodeIfPresent(VMDisplayConfig.self, forKey: .display) ?? VMDisplayConfig()
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(os, forKey: .os)
    try container.encode(arch, forKey: .arch)
    try platform.encode(to: encoder)
    try container.encode(cpuCount, forKey: .cpuCount)    
    try container.encode(memorySize, forKey: .memorySize)
    try container.encode(macAddress.string, forKey: .macAddress)
    try container.encode(display, forKey: .display)
  }

  mutating func setCPU(cpuCount: Int) throws {
    self.cpuCount = cpuCount
  }

  mutating func setMemory(memorySize: UInt64) throws {
    self.memorySize = memorySize
  }
}
