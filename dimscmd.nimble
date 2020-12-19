# Package

version       = "0.2.0"
author        = "Jake Leahy"
description   = "A command handler for the dimscord discord library"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0"
requires "dimscord >= 1.2.1"

task ex, "Runs the example":
    exec("nim r -d:ssl example")
