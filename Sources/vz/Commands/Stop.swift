import ArgumentParser
import Foundation
import Virtualization

struct Stop: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "stop vm")

    @Argument(help: "vm name", completion: .custom(completeVMName))
    var name: String

    func validate() throws {
        let dir = Home.shared.vmDir(name)
        if !dir.initialized() {
            throw ValidationError("vm not initialized, name=\(name)")
        }
        if dir.pid() == nil {
            throw ValidationError("vm is not running, name=\(name)")
        }
    }

    func run() async throws {
        let dir = Home.shared.vmDir(name)
        let pid = dir.pid()
        if let pid = pid {
            Logger.info("stop vm, name=\(name), pid=\(pid)")
            kill(pid, SIGINT)
        }
        try await waitUntilStopped(dir)
    }

    private func waitUntilStopped(_ dir: VMDirectory) async throws {
        var attempts = 0
        while attempts < 20 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if dir.pid() == nil {
                throw CleanExit.message("vm stopped")
            }
            attempts = attempts + 1
        }
        Logger.error("failed to stop vm")
        throw ExitCode.failure
    }
}
