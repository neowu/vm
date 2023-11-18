import ArgumentParser
import Dispatch
import Foundation
import SwiftUI

struct Create: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "create a vm")

  @Argument(help: "vm name")
  var name: String

  func validate() throws {
    throw ValidationError("hello")
  }

  func run() async throws {
    print("hello world")
  }
}
