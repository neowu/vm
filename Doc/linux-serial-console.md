# just memo, not working example

# setup serial console, 

must use VZLinuxBootLoader, with command line to use hvc0,
and update /etc/inittab, to add hvc0 same as tty1-6


```swift
vzConfig.serialPorts = [createConsole()]

private func createBootLoader() -> VZBootLoader {
    if dir.dir.file("vmlinuz").exists() {
        Logger.info("use linux kernel boot loader")
        let bootLoader = VZLinuxBootLoader(kernelURL: dir.dir.file("vmlinuz").url)
        bootLoader.initialRamdiskURL = dir.dir.file("initrd.img").url
        // refer to https://wiki.alpinelinux.org/wiki/Create_a_Bootable_Device
        bootLoader.commandLine = "console=hvc0 alpine_dev=sda2:vfat modules=loop,squashfs,cramfs,sd-mod,usb-storage,ext4 quiet"
        return bootLoader
    }
    ...
}

var handles: [FileHandle] = []

func createConsole() -> VZSerialPortConfiguration {
        NSLog("create console")
        let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()

        // var fd: Int32 = 0
        // var ttys_fd: Int32 = 0
        // var ptyname: [CChar] = Array(repeating: 0, count: 32)
        // let result = ptyname.withUnsafeMutableBytes { namePtr in
        //     openpty(&fd, &ttys_fd, namePtr.baseAddress?.assumingMemoryBound(to: CChar.self), nil, nil)
        // }
        // NSLog("\(result), pty=\(String.init(cString: ptyname))")
        // let handle = FileHandle(fileDescriptor: fd)

        let tty = posix_openpt(O_RDWR)
        grantpt(tty)
        unlockpt(tty)
        let handle = FileHandle.init(fileDescriptor: tty)
        handles.append(handle)

        let name = String.init(cString: ptsname(tty))
        let ttyHandle = FileHandle.init(forUpdatingAtPath: name)
        handles.append(ttyHandle!)

        NSLog("tty=\(tty), path=\(name)")

        let stdioAttachment = VZFileHandleSerialPortAttachment(
            fileHandleForReading: handle,
            fileHandleForWriting: handle)

        consoleConfiguration.attachment = stdioAttachment

        return consoleConfiguration
    }

func createConsole() -> VZSerialPortConfiguration {
    let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()

    let inputFileHandle = FileHandle.standardInput
    let outputFileHandle = FileHandle.standardOutput

    // Put stdin into raw mode, disabling local echo, input canonicalization,
    // and CR-NL mapping.
    var attributes = termios()
    tcgetattr(inputFileHandle.fileDescriptor, &attributes)
    attributes.c_iflag &= ~tcflag_t(ICRNL)
    attributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
    tcsetattr(inputFileHandle.fileDescriptor, TCSANOW, &attributes)

    let stdioAttachment = VZFileHandleSerialPortAttachment(
        fileHandleForReading: inputFileHandle,
        fileHandleForWriting: outputFileHandle)

    consoleConfiguration.attachment = stdioAttachment

    return consoleConfiguration
}

```

```sh
screen /dev/ttys003
```