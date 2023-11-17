import ArgumentParser
import Dispatch
import SwiftUI

fileprivate struct VMInfo: Encodable {
  let Source: String
  let Name: String
  let Size: Int
  let Running: Bool
  let State: String
}

struct List: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "List created VMs")

  func run() async throws {
    var infos: [VMInfo] = []
    infos += sortedInfos(try VMStorageLocal().list().map { (name, vmDir) in
      try VMInfo(Source: "local", Name: name, Size: vmDir.sizeGB(), Running: vmDir.running(), State: vmDir.state())
    })

    print(infos.toJSON())    
  }

  private func sortedInfos(_ infos: [VMInfo]) -> [VMInfo] {
    infos.sorted(by: { left, right in left.Name < right.Name })
  }
}
