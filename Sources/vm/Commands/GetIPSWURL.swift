import ArgumentParser
import Virtualization

struct GetIPSWURL: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "get-ipsw-url", 
        abstract: "Get macOS restore image ipsw url",
        discussion: """
        download ipsw file manually, then pass the path to create command
        """
    )

    func run() async throws {
        let url = try await latestIPSWURL()
        print(url.absoluteURL)
    }

    func latestIPSWURL() async throws -> URL {
        let image = try await withCheckedThrowingContinuation { continuation in
            VZMacOSRestoreImage.fetchLatestSupported() { result in
                continuation.resume(with: result)
            }
        }
        return image.url
    }
}