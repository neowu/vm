import ArgumentParser
import Foundation

@main
struct Main: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vz",
        version: "1.0.0",
        subcommands: [
            Create.self,
            List.self,
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
