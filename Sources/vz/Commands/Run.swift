import ArgumentParser
import Foundation
import SwiftUI
import Virtualization

struct Run: AsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "run vm")

  @Argument(help: "vm name")
  var name: String

  @Flag(help: "open UI window")
  var gui: Bool = false

  @Option(help: "additional disk image in read only mode, e.g. --disk=\"ubuntu.iso\"")
  var disk: String

  func validate() throws {
    if !File.exists(Home.shared.vmDir(name).configURL) {
      throw ValidationError("vm not found, name=\(name)")
    }
  }

  @MainActor
  func run() throws {
    signal(SIGINT, SIG_IGN)

    let vmDir = Home.shared.vmDir(name)
    let lock = FileLock(vmDir.configURL)
    if lock == nil || !lock!.lock() {
      Logger.error("vm is already running, name=\(name)")
      throw ExitCode.failure
    }

    let config = try vmDir.config()

    let virtualMachine: VZVirtualMachine
    if config.os == .linux {
      var linux = Linux(vmDir)
      linux.gui = gui
      linux.disk = disk
      virtualMachine = try linux.createVirtualMachine()
    } else {
      throw ExitCode.failure
    }

    let vm = VM(virtualMachine)
    Task {
      vm.start()
    }
    let signal = DispatchSource.makeSignalSource(signal: SIGINT)
    signal.setEventHandler {
      Task {
        try await vm.stop()
      }
    }
    signal.activate()

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
}
