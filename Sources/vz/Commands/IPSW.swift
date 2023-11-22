import ArgumentParser
import Virtualization

struct IPSW: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "get macOS restore image ipsw url",
        discussion: """
            download ipsw file manually, then use in create command
            """
    )

    func run() async throws {
        let url = try await latestIPSWURL()
        print(url.absoluteURL)
    }

    func latestIPSWURL() async throws -> URL {
        let image = try await withCheckedThrowingContinuation { continuation in
            VZMacOSRestoreImage.fetchLatestSupported { result in
                continuation.resume(with: result)
            }
        }
        return image.url
    }
}
