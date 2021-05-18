# Package

version       = "1.1.1"
author        = "Jake Leahy"
description   = "A command handler for the dimscord discord library"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0"
requires "dimscord#d3a127d"

task ex, "Runs the example":
    exec "nim r -d:dimscordDebug -d:ssl example"

task docs, "Generates the documentation":
    exec "nimble doc --project --index:on --git.url:https://github.com/ire4ever1190/dimscmd --outdir:docs/ src/dimscmd.nim"
