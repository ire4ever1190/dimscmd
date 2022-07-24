# Package

version       = "1.3.3"
author        = "Jake Leahy"
description   = "A command handler for the dimscord discord library"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0"
requires "dimscord >= 1.3.0"

task ex, "Runs the example":
  exec "nim r -d:dimscordDebug -d:ssl example"

