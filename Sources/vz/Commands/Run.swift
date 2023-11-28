import ArgumentParser
import Foundation
import Virtualization

struct Run: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "run vm")

    @Argument(help: "vm name", completion: .custom(completeVMName))
    var name: String

    @Flag(name: .short, help: "run vm in background")
    var detached: Bool = false

    @Flag(help: "open UI window")
    var gui: Bool = false

    @Option(help: "attach disk image in read only mode, e.g. --mount=\"debian.iso\"", completion: .file())
    var mount: Path?

    @Option(help: ArgumentHelp(visibility: .hidden))
    var logPath: Path?

    func validate() throws {
        if detached {
            if gui || mount != nil {
                throw ValidationError("-d must not be used with --gui and --mount")
            }
            let logFile = Path("~/Library/Logs/vz.log")
            if logFile.exists() && !logFile.writable() {  // freopen() creates file if not exists
                throw ValidationError("detach mode log file is not writable, file=\(logFile)")
            }
        }
        let vmDir = Home.shared.vmDir(name)
        if !vmDir.initialized() {
            throw ValidationError("vm not initialized, name=\(name)")
        }
        if vmDir.pid() != nil {
            throw ValidationError("vm is running, name=\(name)")
        }
        if let mount = mount, !mount.exists() {
            throw ValidationError("mount file not exits, mount=\(mount)")
        }
        let config = try vmDir.loadConfig()
        if let _ = config.rosetta {
            if config.os != .linux {
                throw ValidationError("rosetta must be used with linux guest")
            }
            if VZLinuxRosettaDirectoryShare.availability != .installed {
                throw ValidationError("rosetta is not available on host")
            }
        }
        if config.os == .macOS && !gui {
            // sonoma screen share high performance mode doesn't work with NAT, so better use vm view than standard mode
            throw ValidationError("macOS must be used with gui")
        }
    }

    @MainActor
    func run() throws {
        let vmDir = Home.shared.vmDir(name)
        let config = try vmDir.loadConfig()

        // must hold lock reference, otherwise fd will de deallocated, and release all locks
        let lock = vmDir.lock()
        if lock == nil {
            Logger.error("vm is already running, name=\(name)")
            throw ExitCode.failure
        }

        if detached == true {
            try runInBackground()
        }

        if let logPath = logPath {
            freopen(logPath.path, "a", stdout)
            freopen(logPath.path, "a", stderr)
        }

        let virtualMachine: VZVirtualMachine
        if config.os == .linux {
            var linux = Linux(vmDir)
            linux.gui = gui
            linux.mount = mount
            virtualMachine = try linux.createVirtualMachine(config)
        } else {
            var macOS = MacOS(vmDir)
            macOS.mount = mount
            virtualMachine = try macOS.createVirtualMachine(config)
        }

        let vm = VM(virtualMachine)

        // must hold signals reference, otherwise it will de deallocated
        var signals: [DispatchSourceSignal] = []
        signals.append(handleSignal(SIGINT, vm))
        signals.append(handleSignal(SIGTERM, vm))

        Task {
            vm.start()
        }

        if gui {
            runUI(vm, config.os == .macOS)
        } else {
            runCLI()
        }
    }

    func runInBackground() throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: Bundle.main.executablePath!)
        let logFile = Path("~/Library/Logs/vz.log")
        task.arguments = ["run", name, "--log-path", logFile.path]
        task.launch()
        throw CleanExit.message("vm launched in background, check log in \(logFile)")
    }

    func runCLI() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.run()
    }

    func runUI(_ vm: VM, _ automaticallyReconfiguresDisplay: Bool) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)

        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 1024, 768),
            styleMask: [.titled, .resizable, .closable], backing: .buffered, defer: false, screen: nil)
        window.title = name
        window.delegate = vm

        let menu = NSMenu()
        let menuItem = NSMenuItem()
        menuItem.submenu = NSMenu()
        menuItem.submenu?.items = [
            NSMenuItem(
                title: "Stop \(name)...",
                action: #selector(NSWindow.close), keyEquivalent: "q")
        ]
        menu.items = [menuItem]
        app.mainMenu = menu

        let machineView = VZVirtualMachineView(frame: window.contentLayoutRect)
        machineView.capturesSystemKeys = true
        machineView.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        machineView.virtualMachine = vm.machine
        machineView.autoresizingMask = [.width, .height]

        window.contentView?.addSubview(machineView)
        window.makeKeyAndOrderFront(nil)

        app.run()
    }

    func handleSignal(_ sig: Int32, _ vm: VM) -> DispatchSourceSignal {
        signal(sig, SIG_IGN)
        let signal = DispatchSource.makeSignalSource(signal: sig)
        signal.setEventHandler {
            Task {
                try await vm.stop()
            }
        }
        signal.activate()
        return signal
    }
}

func completeVMName(_ arguments: [String]) -> [String] {
    return Home.shared.vmDirs().map({ $0.name })
}
