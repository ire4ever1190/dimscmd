import std/macros
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
    # echo prc.treeRepr()
    let docString = prc.findChild(it.kind == nnkCommentStmt)
    if docString != nil:
        result = docString.strVal

proc getParameterDescription*(prc: NimNode, name: string): string =
    ## Gets the value of the help pragma that is attached to a parameter
    ## The pragma is attached to the parameter like so
    ## cmd.addChat("echo") do (times {.help: "The number of times to time"}) = discard
    var pragma = findChild(prc, it.kind == nnkPragma and it[0][0].strVal == "help")
    if pragma != nil:
        result = pragma[0][1].strVal


proc getParamTypes*(prc: NimNode): seq[NimNode] =

    expectKind(prc, nnkDo)
    for node in prc.params():
        if node.kind == nnkIdentDefs:
            var
                helpMsg = ""
                name: string
            # Check if the first pragma is {.help.} TODO, make this more robust
            if node[0].kind == nnkPragmaExpr and node[0][1][0][0].strVal == "help":
                helpMsg = $node[0][1][0][1]
                name    = $node[0][0]
            else:
                name = $node[0] # Name isn't in a pragma so you can get it directly
            let paramType = node[1]
            # You might be thinking "hey Jake, what is this?", well
            # I want to encode the type, name, and help message for each parameter so that a typed macro
            # can sym the type in the context of the caller which means I need to pass correct nim code.
            # and this was my best idea, passing a cast statement with the name and message seperated by a null char
            # Who ever is reading this, please implement a way for macros to bindSym int the context that they were called
            # without doing hacks like passing a call to a new macro and stuff
            # TODO not tired Jake: please do a system that isn't hacky (and don't make someone else touch this spaget)
            # Some ideas for future me
            # * pass in the full handler and just get this info with the index
            let encodedMisc = name & $chr(0) & helpMsg
            let parameter = nnkCast.newTree(
                paramType, encodedMisc.newStrLitNode()
            )
            parameter.copyLineInfo(node)
            result &= parameter

proc getEnumOptions(enumObject: NimNode): seq[EnumOption] =
    for node in enumObject:
        if node.kind != nnkEmpty:
            let name = node.strVal
            let value = if node.getImpl().kind == nnkNilLit:
                name
            else:
                node.getImpl().strVal
            result &= EnumOption(
                name: name,
                value: value
            )

    discard

{.experimental: "dynamicBindSym".}
proc getParameters*(parameters: NimNode): seq[ProcParameter] {.compileTime.} =
    ## Gets the both the name, type, and help message of each parameter and returns it in a sequence
    for paramNode in parameters.children():
        paramNode.expectKind(nnkCast)
        let
            kind    = paramNode[0]
            encodes = paramNode[1].strVal.split(chr(0))
            # Get values that are encoded
            name    = encodes[0]
            helpMsg = encodes[1]

        var
            outer: string
            inner: string
        var parameter = ProcParameter(name: name)
        # toStrLit is used since it works better with types that are Option[T]
        discard ($kind.toStrLit()).scanf("$w[$w]", outer, inner)
        let outLowered = outer.toLowerAscii() # For comparison without modifying the orignial variable
        let
            typeInstance = kind.getTypeInst()
            typeImplementation = kind.getTypeImpl()
        if typeInstance.kind == nnkBracketExpr:
            parameter.optional = typeInstance[0].eqIdent("Option")
            parameter.sequence = typeInstance[0].eqIdent("seq")

        if typeImplementation.kind == nnkEnumTy:
            parameter.isEnum = true
            parameter.options = getEnumOptions(typeImplementation)
        # parameter.isEnum   = typeInstance
        parameter.originalKind = (if parameter.optional or parameter.sequence: inner else: outer)
        # Check if the type is an alias of a different type
        if typeAlias.hasKey(parameter.originalKind):
            parameter.originalKind = typeAlias[parameter.originalKind]
        parameter.kind = parameter.originalKind
                            .toLowerAscii()
                            .replace("_", "")
        parameter.future = parameter.kind in ["guildchannel", "user", "role"] or outLowered == "future"

        parameter.help = helpMsg
        result.add parameter
    # echo parameters.treeRepr()
export tables
