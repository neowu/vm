import Foundation
import Virtualization

struct MacOSInstaller {
    let virtualMachine: VZVirtualMachine
    let ipsw: Path

    init(_ virtualMachine: VZVirtualMachine, _ ipsw: Path) {
        self.virtualMachine = virtualMachine
        self.ipsw = ipsw
    }

    @MainActor
    func install() async throws {
        var observers: [NSKeyValueObservation] = []  // must hold observer references during installation to print process
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task {
                let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: ipsw.url)
                Logger.info("instal macOS")
                let observer = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { (progress, change) in
                    Logger.info("instal progress: \(Int(change.newValue! * 100))%")
                }
                observers.append(observer)
                installer.install { result in
                    if case let .failure(error) = result {
                        Logger.error("failed to install, error=\(error))")
                        exit(EXIT_FAILURE)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        Logger.info("macOS install finished")
    }
}
