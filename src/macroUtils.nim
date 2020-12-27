import macros

## Utilites for use in macros

type
    ProcParameter* = tuple[name: string, kind: string]

proc getDoc*(prc: NimNode): string =
    ## Gets the doc string for a function
    for node in prc:
        if node.kind == nnkStmtList:
            for innerNode in node:
                if innerNode.kind == nnkCommentStmt:
                    return innerNode.strVal

proc getParameters*(prc: NimNode): seq[ProcParameter] =
    ## Gets the both the name and type of each parameter and returns it in a sequence
    ## [0] is the name of the parameter
    ## [1] is the type of the parameter
    for node in prc:
        if node.kind == nnkFormalParams:
            for paramNode in node:
                if paramNode.kind == nnkIdentDefs:
                    result.add((paramNode[0].strVal, paramNode[1].strVal))

