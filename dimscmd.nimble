# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "A command handler for the dimscord discord library"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.2.6"
requires "dimscord >= 1.2.1"

task ex, "Runs the example":
    exec("nim r -d:ssl example")
