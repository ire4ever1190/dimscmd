import macros
import std/with
import tables

## Utilites for use in macros

type
    ProcParameter* = tuple[name: string, kind: string, help: string]

const
    optionPrefixes* = {'$', '%'} ## $ means variables, % means variable help

proc getDoc*(prc: NimNode): string =
    ## Gets the doc string for a procedure
    expectKind(prc, nnkDo)
    let docString = prc.findChild(it.kind == nnkCommentStmt)
    if docString != nil:
        result = docString.strVal

proc getParameterDescription*(prc: NimNode, name: string): string =
    ## Gets the value of the help pragma that is attached to a parameter
    #expectKind(prc, nnkDo)
    var pragma = findChild(prc, it.kind == nnkPragma)
    if pragma != nil:
        result = pragma[0][1].strVal

proc getParameters*(prc: NimNode): seq[ProcParameter] =
    ## Gets the both the name, type, and help message of each parameter and returns it in a sequence
    #expectKind(prc, nnkDo)
    for node in prc:
        if node.kind == nnkFormalParams:
            for paramNode in node:
                if paramNode.kind == nnkIdentDefs:
                    var parameter: ProcParameter
                    with parameter:
                        name = paramNode[0].strVal
                        kind = $paramNode[1].toStrLit # toStrLit is used since it works better with types that are Option[T]
                        help = prc.getParameterDescription(parameter.name)
                    result.add parameter
export tables
