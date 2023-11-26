import ArgumentParser
import Foundation
import Virtualization

struct Stop: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "stop vm")

    @Argument(help: "vm name", completion: .custom(completeVMName))
    var name: String

    func validate() throws {
        let vmDir = Home.shared.vmDir(name)
        if !vmDir.initialized() {
            throw ValidationError("vm not initialized, name=\(name)")
        }
        if vmDir.pid() == nil {
            throw ValidationError("vm is not running, name=\(name)")
        }
    }

    func run() async throws {
        let vmDir = Home.shared.vmDir(name)
        let pid = vmDir.pid()
        if let pid = pid {
            Logger.info("stop vm, name=\(name), pid=\(pid)")
            kill(pid, SIGINT)
        }
        try await waitUntilStopped(vmDir)
    }

    private func waitUntilStopped(_ vmDir: VMDirectory) async throws {
        var attempts = 0
        while attempts < 20 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if vmDir.pid() == nil {
                throw CleanExit.message("vm stopped")
            }
            attempts = attempts + 1
        }
        Logger.error("failed to stop vm")
        throw ExitCode.failure
    }
}
