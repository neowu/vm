import ArgumentParser
import Darwin
import Foundation

@main
struct Main: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "vz",
    version: "1.0.0",
    subcommands: [
      Create.self,
      Clone.self,
      Run.self,
      Set.self,
      Get.self,
      List.self,
      Rename.self,
      Stop.self,
      Delete.self,
      GetIPSWURL.self,
    ])

  public static func main() async throws {
    // Ensure the default SIGINT handled is disabled,
    // otherwise there's a race between two handlers
    signal(SIGINT, SIG_IGN);
    // Handle cancellation by Ctrl+C ourselves
    let task = withUnsafeCurrentTask { $0 }!
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
    sigintSrc.setEventHandler {
      task.cancel()
    }
    sigintSrc.activate()

    // Set line-buffered output for stdout
    setlinebuf(stdout)

    // Parse and run command
    do {
      var command = try parseAsRoot()

      // Run garbage-collection before each command (shouldn't take too long)
      if type(of: command) != type(of: Clone()) {
        do {
          try Config().gc()
        } catch {
          fputs("Failed to perform garbage collection!\n\(error)\n", stderr)
        }
      }

      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      // Handle a non-ArgumentParser's exception that requires a specific exit code to be set
      if let errorWithExitCode = error as? HasExitCode {
        fputs("\(error)\n", stderr)

        Foundation.exit(errorWithExitCode.exitCode)
      }

      // Handle any other exception, including ArgumentParser's ones
      exit(withError: error)
    }
  }
}
