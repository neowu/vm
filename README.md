A lightweight virtual machine tool, for personal use. tested with Apple M2 CPU (MacBook Pro) / macOS Sonoma

# How to build
install XCode for macOS SDK
```sh
sudo xcode-select -switch {where xcode installed}/Xcode.app/Contents/Developer
./Scripts/debug.sh
```

# Features
* create and run both Linux and MacOS VM
* run in GUI or detached mode

# Usage
```
OVERVIEW: manage virtual machines

USAGE: vz <subcommand>

OPTIONS:
  --version               Show the version.
  --help                  Show help information.

SUBCOMMANDS:
  create                  create vm
  ls                      list vm status
  run                     run vm
  stop                    stop vm
  ipsw                    get macOS restore image ipsw url
  resize                  increase disk image size

  See 'vz help <subcommand>' for detailed help.
```

# Install zsh completion
```sh
vz --generate-completion-script zsh | sudo tee /usr/local/share/zsh/site-functions/_vz
```

# Notes
* use `arp -an` to find ip, or check `cat /var/db/dhcpd_leases`
* for local docker host, refer to [setup-docker-host.md](Doc/setup-docker-host.md)