import std/macros
import std/with
import std/strutils
import std/strscans
import std/tables
import common
import tables
import std/sequtils
import std/sugar

## Utilites for use in macros

# Table used if a type has an alias
const typeAlias = @{
    "Channel": "GuildChannel"
}.toTable()

proc getDoc*(prc: NimNode): string =
    ## Gets the doc string for a procedure
    let docString = prc.findChild(it.kind == nnkCommentStmt)
    if docString != nil:
        result = docString.strVal

proc getParameterDescription*(prc: NimNode, name: string): string =
    ## Gets the value of the help pragma that is attached to a parameter
    ## The pragma is attached to the parameter like so
    ## cmd.addChat("echo") do (times {.help: "The number of times to time"}: int) = discard
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

proc parameterDummy(t: typedesc, name, helpMsg: string) =
  ## Dummy proc to be able to sym procs
  discard
  
macro lookupUsing(x: typed): typedesc =
  result = ident $x[3][1][0].getTypeInst()


proc getParamTypes*(prc: NimNode): seq[NimNode] =
    expectKind(prc, nnkDo)
    var previousParams: seq[string] # Store name of current parameters to stop redefine errors
    for node in prc.params():
        if node.kind == nnkIdentDefs:
            # The parameter type is always the second last item
            let paramType = if node[^2].kind != nnkEmpty:
                node[^2]
              else:
                # Param is using `using` variable
                # So we need to lookup the type that the using points to
                # Since it is not a normal thing we need to make it be the parameter 
                # of a dummy proc
                newCall(bindSym "lookupUsing", parseStmt("proc foo(" & $node[0] & ") = discard"))
            
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
                let parameter = newCall(
                    "parameterDummy".bindSym(),
                    paramType,
                    name.newLit(),
                    helpMsg.newLit()
                )
                parameter.copyLineInfo(node)
                result &= parameter

proc getEnumOptions(enumObject: NimNode): seq[EnumOption] =
    for node in enumObject.getTypeInst().getImpl()[2]: # Loop over the enum elements
        if node.kind != nnkEmpty:
            var
                name: string
                value: string
            case node.kind:
                of nnkEnumFieldDef:
                    name = node[0].strVal
                    # We only care about the string value
                    value = if node[1].kind == nnkStrLit:
                                node[1].strVal
                            else:
                                $node[1].intVal
                of nnkSym:
                    name = node.strVal
                    value = name
                else: discard
            # When the user defines a string value for an enum they are changing
            # its name, not its value so switch to reflect that
            result &= EnumOption(
                name: value,
                value: name
            )

proc getArrayOptions(node: NimNode): tuple[min, max: int, kind: string] =
    ## Gets the min, max, and kind from an array node e.g.
    ##
    ## .. code-block:: nim
    ##
    ##  var a: array[4, int]
    ##  # min = 4
    ##  # max = 4
    ##  # kind = int
    ##
    ##  var b: array[0..4, int]
    ##  # min = 0
    ##  # max = 4
    ##  # kind = int
    ##
    node.expectKind(nnkBracketExpr)
    result.kind = $node[2]
    let lengthNode = node[1]
    case lengthNode.kind:
        of nnkInfix:
            discard
        else:
            "Expected length parameter for array in form `min..max` or `max`".error(lengthNode)

{.experimental: "dynamicBindSym".}
proc getParameters*(parameters: NimNode): seq[ProcParameter] {.compileTime.} =
    ## Gets the both the name, type, and help message of each parameter and returns it in a sequence
    for paramNode in parameters.children():
        let
          kind = paramNode[1]
          name = paramNode[2].strVal
          helpMsg = paramNode[3].strVal
        
        var
            outer: string
            inner: string
        var parameter = ProcParameter(name: name)
        discard ($kind.toStrLit()).scanf("$w[$w]", outer, inner)
        # let outLowered = outer.toLowerAscii() # For comparison without modifying the orignial variable
        # The first .getTypeImpl returns a type desc node so it needs to be ran twice
        # to get the actual implementation of the type
        let typeImplementation = kind.getTypeImpl()[1].getTypeImpl()
        if kind.kind == nnkBracketExpr:
            parameter.optional = kind[0].eqIdent("Option")
            parameter.sequence = kind[0].eqIdent("seq")
        case typeImplementation.kind
            of nnkEnumTy:
                parameter.isEnum = true
                parameter.options = getEnumOptions(typeImplementation)
            # of nnkBracketExpr:
            #     if typeImplementation[0].eqIdent("array"):
            #         parameter.array = true
            #         let (min, max, kind) = typeImplementation.getArrayOptions()
            else:
                discard

        parameter.kind = (if parameter.optional or parameter.sequence: inner else: outer)
        # Check if the type is an alias of a different type
        if typeAlias.hasKey(parameter.kind):
            parameter.kind = typeAlias[parameter.kind]

        # Check if the return type is known to be a future type or is explicitly Future[T]
        parameter.future =
            ["GuildChannel", "User", "Role"].any(it => parameter.kind.eqIdent(it)) or
            outer.eqIdent("Future")
        parameter.help = helpMsg
        result.add parameter
export tables
