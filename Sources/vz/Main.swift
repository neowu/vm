import ArgumentParser
import Foundation

@main
struct Main: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vz",
        abstract: "manage virtual machines",
        version: "0.4.1",
        subcommands: [
            Create.self,
            List.self,
            Run.self,
            Stop.self,
            IPSW.self,
            Resize.self,
        ],
        helpNames: NameSpecification.long)

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
