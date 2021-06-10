import macros
import std/with
import std/strutils
import std/strscans
import std/strtabs
import common
import tables

## Utilites for use in macros

# Table used if a type has an alias
let typeAlias {.compileTime.} = {
    "Channel": "GuildChannel"
}.newStringTable()

proc getDoc*(prc: NimNode): string =
    ## Gets the doc string for a procedure
    let docString = prc
        .findChild(it.kind == nnkStmtList)
        .findChild(it.kind == nnkCommentStmt)
    if docString != nil:
        result = docString.strVal

proc getParameterDescription*(prc: NimNode, name: string): string =
    ## Gets the value of the help pragma that is attached to a parameter
    ## The pragma is attached to the parameter like so
    ## cmd.addChat("echo") do (times {.help: "The number of times to time"}) = discard
    var pragma = findChild(prc, it.kind == nnkPragma and it[0][0].strVal == "help")
    if pragma != nil:
        result = pragma[0][1].strVal

proc bindSymbols*(prc: NimNode): NimNode = discard
    # for node in prc:
    #     if node.kind == nnkFormlParams:
    #         for paramNode in node:

proc getParameters*(prc: NimNode): seq[ProcParameter] {.compileTime.} =
    ## Gets the both the name, type, and help message of each parameter and returns it in a sequence
    #expectKind(prc, nnkDo)
    for paramNode in prc.findChild(it.kind == nnkFormalParams):
        if paramNode.kind == nnkIdentDefs:
            var parameter: ProcParameter
            # If the parameter has a pragma attached then a bit more work is needed to get the name of the parameter
            if paramNode[0].kind == nnkPragmaExpr:
               parameter.name = paramNode[0][0].strVal
            else:
                parameter.name = paramNode[0].strVal
            var
                outer: string
                inner: string
            # toStrLit is used since it works better with types that are Option[T]
            discard ($paramNode[1].toStrLit()).scanf("$w[$w]", outer, inner)
            let outLowered = outer.toLowerAscii() # For comparison without modifying the orignial variable
            parameter.optional = outLowered == "option"
            parameter.sequence = outLowered == "seq"
            parameter.originalKind = (if parameter.optional or parameter.sequence: inner else: outer)
            # Check if the type is an alias of a different type
            if typeAlias.hasKey(parameter.originalKind):
                parameter.originalKind = typeAlias[parameter.originalKind]
            parameter.kind = parameter.originalKind
                                .toLowerAscii()
                                .replace("_", "")
            parameter.future = parameter.kind in ["guildchannel", "user", "role"] or outLowered == "future"

            parameter.help = prc.getParameterDescription(parameter.name)
            result.add parameter
export tables
