import ArgumentParser
import Foundation
import SwiftUI
import Virtualization

struct Run: AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "run vm")

    @Argument(help: "vm name", completion: .custom(completeVMName))
    var name: String

    @Flag(help: "open UI window")
    var gui: Bool = false

    @Option(help: "attach disk image in read only mode, e.g. --mount=\"ubuntu.iso\"", completion: .file())
    var mount: String?

    @Flag(
        help: ArgumentHelp(
            "attach rosetta share to the linux guest",
            discussion: """
                refer to https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta#3978496
                """))
    var rosetta: Bool = false

    func validate() throws {
        let vmDir = Home.shared.vmDir(name)
        if !vmDir.initialized() {
            throw ValidationError("vm not initialized, name=\(name)")
        }
        if vmDir.pid() != nil {
            throw ValidationError("vm is running, name=\(name)")
        }
        if rosetta && VZLinuxRosettaDirectoryShare.availability != .installed {
            throw ValidationError("rosetta is not available on host")
        }
        let config = try vmDir.loadConfig()
        if rosetta && config.os != .linux {
            throw ValidationError("rosetta must use with linux guest")
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

        let virtualMachine: VZVirtualMachine
        if config.os == .linux {
            var linux = Linux(vmDir)
            linux.gui = gui
            linux.mount = mount
            virtualMachine = try linux.createVirtualMachine(config, rosetta)
        } else {
            throw ExitCode.failure
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
            runUI(vm)
        } else {
            runInBackground()
        }
    }

    func runInBackground() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.run()
    }

    func runUI(_ vm: VM) {
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
        machineView.automaticallyReconfiguresDisplay = false
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
