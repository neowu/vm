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

    let app = NSApplication.shared
    if gui {
      app.setActivationPolicy(.regular)
      app.activate(ignoringOtherApps: true)
      NSMenu.setMenuBarVisible(false)

      let pixels = config.displayInPixels()
      let window = NSWindow(
        contentRect: NSMakeRect(0, 0, CGFloat(pixels.0), CGFloat(pixels.1)),
        styleMask: [.titled, .resizable, .closable], backing: .buffered, defer: false, screen: nil)
      window.title = name

      let machineView = VZVirtualMachineView(frame: window.contentLayoutRect)
      machineView.capturesSystemKeys = true
      machineView.automaticallyReconfiguresDisplay = false
      machineView.virtualMachine = virtualMachine
      machineView.autoresizingMask = [.width, .height]

      window.contentView?.addSubview(machineView)
      window.makeKeyAndOrderFront(nil)
    } else {
      app.setActivationPolicy(.prohibited)
    }
    app.run()
  }
}
