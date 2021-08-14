# Package

version       = "1.2.2"
author        = "Jake Leahy"
description   = "A command handler for the dimscord discord library"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0"
# requires "https://github.com/krisppurg/dimscord#eb1b171"
requires "dimscord"

task ex, "Runs the example":
    exec "nim r -d:dimscordDebug -d:ssl example"

task docs, "Generates the documentation":
    exec "nimble doc --project --index:on --git.url:https://github.com/ire4ever1190/dimscmd --outdir:docs/ src/dimscmd.nim"
