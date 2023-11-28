virtual machine tool, for personal use. tested with Apple M2 CPU (MacBook Pro) / macOS Sonoma

# features
* create and run both Linux and MacOS VM
* run in GUI or detached mode

# usage
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

# install zsh completion
```sh
vz --generate-completion-script zsh | sudo tee /usr/local/share/zsh/site-functions/_vz
```

# notes
* use `arp -an` to find ip, or check `cat /var/db/dhcpd_leases`