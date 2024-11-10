# Package

version       = "0.1.0"
author        = "thatrandomperson5"
description   = "Web UI for backend SSH connections."
license       = "GPL-3.0-only"
srcDir        = "src"
binDir        = "builds"

when defined(release):
  bin         = @["wssh"]
else:
  bin         = @["wssh", "wsshprintpacket"]
  
installDirs   = @["public"]
installExt    = @["nims"]
skipFiles     = @["public/test.html", "public/static/test.nim.js"]

# Tasks

task buildTestFrontend, "build test js":
  exec "nim js -o:\"public/static/test.nim.js\" src/frontend/test.nim"

# Dependencies

requires "nim ^= 2.0.8"
requires "ssh2 ^= 0.1.8"
requires "jester ^= 0.6.0"
requires "ws ^= 0.5.0"
requires "cligen ^= 1.7.3"
requires "flatty ^= 0.3.4"
requires "karax ^= 1.3.3"