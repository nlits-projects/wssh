# Package

version       = "0.1.0"
author        = "thatrandomperson5"
description   = "Web UI for backend SSH connecitons."
license       = "GPL-3.0-only"
srcDir        = "src"
binDir        = "builds"
bin           = @["wssh"]
installDirs   = @["public"]
installExt    = @["nims"]

# Dependencies

requires "nim ^= 2.0.8"
requires "ssh2 ^= 0.1.8"
requires "jester ^= 0.6.0"
requires "ws ^= 0.5.0"
requires "cligen ^= 1.7.3"