import std/macros
import std/with
import std/strutils
import std/strscans
import std/strtabs
import common
import tables
import std/sequtils
import std/sugar

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

func makeObjectConstr(name, kind: NimNode, values: seq[(string, NimNode)]): NimNode =
    ## Creates NimNode for an object construction
    result = nnkObjConstr.newTree(
        nnkBracketExpr.newTree(
            name,
            kind
        )
    )
    for value in values:
        result &= nnkExprColonExpr.newTree(
            value[0].ident(),
            value[1]
        )

func getObjectConstrParam(constr: NimNode, key: string): NimNode =
    ## Returns a parameter with name from an object construction
    for param in constr[1..^1]: # Skip the name at the start
        if param[0].eqIdent(key):
            return param

type
    Parameter[T] = object
        name*: string
        helpMsg*: string


proc getParamTypes*(prc: NimNode): seq[NimNode] =
    expectKind(prc, nnkDo)
    var previousParams: seq[string] # Store name of current parameters to stop redefine errors
    for node in prc.params():
        if node.kind == nnkIdentDefs:
            # The parameter type is always the second last item
            let paramType = node[^2]
            # But there can be any number of parameters before the param type
            # so we iterate over them and add them to the parameter list
            for param in node[0 ..< ^2]:
                var
                    helpMsg = ""
                    name: string
                if param.kind == nnkPragmaExpr and param[1][0][0].eqIdent "help":
                    helpMsg = $param[1][0][1]
                    name    = $param[0]
                else:
                    name = $param # Name isn't in a pragma so you can get it directly

                # Check that the parameter hasn't been used before
                if name in previousParams:
                    # If it has, then provide a better error message
                    error("You have already defined the parameter `" & name & "` previously", param)
                previousParams &= name
                # Pass an object construction which contains all
                # the variables needed. This is done so that the parameter type
                # is symed and so we can do some more operations on it
                let parameter = makeObjectConstr(
                    "Parameter".bindSym(),
                    paramType,
                    @{
                        "name": name.newLit(),
                        "helpMsg": helpMsg.newLit(),
                    }
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
        paramNode.expectKind(nnkObjConstr)
        # Get the values out of the object construction
        let
            kind    = paramNode[0][1]
            name    = paramNode.getObjectConstrParam("name")[1].strVal()
            helpMsg = paramNode.getObjectConstrParam("helpMsg")[1].strVal()
        var
            outer: string
            inner: string
        var parameter = ProcParameter(name: name)
        # toStrLit is used since it works better with types that are Option[T]
        discard ($kind.toStrLit()).scanf("$w[$w]", outer, inner)
        let outLowered = outer.toLowerAscii() # For comparison without modifying the orignial variable
        # The first .getTypeImpl returns a type desc node so it needs to be ran twice
        # to get the actual implementation of the type
        let typeImplementation = kind.getTypeImpl()[1].getTypeImpl()
        if kind.kind == nnkBracketExpr:
            parameter.optional = kind[0].eqIdent("Option")
            parameter.sequence = kind[0].eqIdent("seq")

        if typeImplementation.kind == nnkEnumTy:
            parameter.isEnum = true
            parameter.options = getEnumOptions(typeImplementation)
        parameter.kind = (if parameter.optional or parameter.sequence: inner else: outer)
        # Check if the type is an alias of a different type
        if typeAlias.hasKey(parameter.kind):
            parameter.kind = typeAlias[parameter.kind]
        # parameter.kind = parameter.originalKind
        #                     .toLowerAscii()
        #                     .replace("_", "")

        parameter.future =
            ["GuildChannel", "User", "Role"].any(it => parameter.kind.eqIdent(it)) or
            outer.eqIdent("Future")

        parameter.help = helpMsg
        result.add parameter
export tables
