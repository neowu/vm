import ArgumentParser
import Foundation

@main
struct Main: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "vz",
    version: "1.0.0",
    subcommands: [
      Create.self
    ])

  public static func main() async throws {
    // disable default sigint
    signal(SIGINT, SIG_IGN)

    do {
      var command = try parseAsRoot()
      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      print("\(error)")
      // Handle any other exception, including ArgumentParser's ones
      exit(withError: error)
    }
  }
}
