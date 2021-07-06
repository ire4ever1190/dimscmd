# Package

version       = "1.2.2"
author        = "Jake Leahy"
description   = "A command handler for the dimscord discord library"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0"
# requires "dimscord == 1.2.5"
requires "https://github.com/ire4ever1190/dimscord#c1699ec"
# requires "dimscord"

task ex, "Runs the example":
    exec "nim r -d:dimscordDebug -d:ssl example"

task docs, "Generates the documentation":
    exec "nimble doc --project --index:on --git.url:https://github.com/ire4ever1190/dimscmd --outdir:docs/ src/dimscmd.nim"
