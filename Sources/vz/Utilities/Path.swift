import ArgumentParser
import Foundation

struct Path: CustomStringConvertible, ExpressibleByArgument {
    let url: URL

    init(_ path: String) {
        url = URL(filePath: NSString(string: path).expandingTildeInPath).standardizedFileURL
    }

    init(_ url: URL) {
        self.url = url
    }

    init(argument: String) {
        self.init(argument)
    }

    func file(_ path: String) -> Path {
        return Path(url.appendingPathComponent(path, isDirectory: false))
    }

    func directory(_ path: String) -> Path {
        return Path(url.appendingPathComponent(path, isDirectory: true))
    }

    func exists() -> Bool {
        return FileManager.default.fileExists(atPath: url.path())
    }

    func writable() -> Bool {
        return FileManager.default.isWritableFile(atPath: url.path())
    }

    var name: String {
        return url.lastPathComponent
    }

    var path: String {
        return url.path()
    }

    var description: String {
        return url.path()
    }
}
