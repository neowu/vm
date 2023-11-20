import ArgumentParser
import Foundation

@main
struct Main: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "vz",
    abstract: "vm management",
    version: "1.0.0",
    subcommands: [
      Create.self,
      Get.self,
      Run.self,
    ])

  public static func main() async {
    do {
      var command = try parseAsRoot()
      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      exit(withError: error)
    }
  }
}
