import macros, strutils, sequtils, tables, algorithm
import ast, types, type_env, top, errors, breeze

proc loadTypeKind(check: NimNode): int =
  var kindType = getType(TypeKind)
  var z = 0
  for child in kindType:
    if child.kind == nnkSym and $child == $check:
      return z
    inc z
  return -1

proc isSeqOfNodes(t: NimNode): bool =
  result = t.kind == nnkBracketExpr and t[0].kind == nnkSym and $t[0] == "seq" and t[1].kind == nnkBracketExpr and t[1][0].kind == nnkSym and $t[1][0] == "ref" and t[1][1].kind == nnkSym and $t[1][1] == "BNode"

proc isNode(t: NimNode): bool =
  result = t.kind == nnkBracketExpr and t[0].kind == nnkSym and $t[0] == "ref" and t[1].kind == nnkSym and $t[1] == "BNode"

proc unexpectedTypeError*(target: string, expected: Type, got: Type): ref RoswellError =
  return newException(RoswellError, 
    "$1:\n  expected $2\n  got      $3" % [
      target,
      simple(expected),
      simple(got)])

proc generateCheck(field: NimNode, fieldType: NimNode, check: NimNode): NimNode =
  var t = getType(BType)
  var typeBranches = t[2][1]
  if isNode(fieldType) or not isSeqOfNodes(fieldType):
    case check.kind:
    of nnkIdent:
      var w = loadTypeKind(check)
      if w > -1:
        if not isNode(fieldType):
          result = quote:
            if `field`.kind != `check`:
              raise newException(RoswellError, "expected field")
        else:
          result = quote:
            if `field`.tag.kind != `check`:
              raise newException(RoswellError, "expected $1" % $`check`)
      else:
        result = quote:
          if `field`.tag != `check`:
            raise newException(RoswellError, "expected $1" % $`check`)
    else:
      result = quote:
        if `field`.tag != `check`:
          raise unexpectedTypeError($`field`, `field`.tag, `check`)
  elif isSeqOfNodes(fieldType):
    var zNode = newIdentNode(!"z")
    if check.kind == nnkPrefix and $check[0] == "@" and check[1].kind == nnkBracket:
      var p = check[1][0]
      if check[1][0].kind == nnkIdent and isUpperAscii(($check[1][0])[0]):
        # prolog var
        
        var declaration = quote:
          var `p`: Type
        result = declaration
        
        var lenCheck = quote:
          if len(`field`) == 0:
            raise newException(RoswellError, "empty $1" % $`field`)
        result.add(lenCheck)
        
        var init = quote:
          `p` = `field`[0].tag
        result.add(init)
    
      var elementNode = newIdentNode(!"element")
      var elementTagNode = newIdentNode(!"elementTag")
      var loopCheck = quote:
        for `elementNode` in `field`:
          var `elementTagNode` = `elementNode`.tag
          if `p` != `elementTagNode`:
            raise unexpectedTypeError("element", `p`, `elementTagNode`)
        
      result.add(loopCheck)
    else:
      result = quote:
        if len(`field`) != len(`check`):
          raise newException(RoswellError, "expected length")
        for `zNode` in low(`field`)..high(`field`):
          if `field`[`zNode`].tag != `check`[`zNode`]:
            raise unexpectedTypeError($`field`[`zNode`], `field`[`zNode`].tag, `check`[`zNode`])


proc generateTag(tag: NimNode): NimNode =
  var resultNode = newIdentNode(!"result")
  result = quote:
    node.tag = `tag`
    `resultNode` = node

proc generateCase(e: int, f: NimNode): NimNode =
  var s = getType(BNode)
  var branches = s[2][1]
  var isBranch = false
  var fields = initTable[string, NimNode]()

  if len(f) > 0 and f[0].kind == nnkReturnStmt:
    return f

  for branch in branches:
    if isBranch:
      if parseInt(treerepr(branch[0]).split(' ')[1]) == e:
        for f in branch[1]:
          fields[$f] = getType(f)
        break
    else:
      isBranch = true

  result = buildMacro:
    stmtList()
  var q = quote:
    echo node
  # result.add(q)
  
  for field, t in fields:
    var fieldLabel = newIdentNode(!field)
    if isSeqOfNodes(t):
      var v = quote:
        var `fieldLabel` = node.`fieldLabel`.mapIt(typecheckNode(it, env))
      result.add(v)
    elif isNode(t):
      var v = quote:
        var `fieldLabel`: Node
        if node.`fieldLabel` != nil:
          `fieldLabel` = typecheckNode(node.`fieldLabel`, env)
      result.add(v)

  for line in f:
    case line.kind:
    of nnkAsgn, nnkVarSection:
      result.add(line)
    of nnkInfix:
      if $line[0] notin @["<=", "=>"]:
        result.add(line)
      elif $line[0] == "<=" and line[1].kind == nnkIdent and fields.hasKey($line[1]):
        result.add(generateCheck(line[1], fields[$line[1]], line[2]))
      elif line[1].kind == nnkIdent and $line[1] == "emit":
        result.add(generateTag(line[2]))
      else:
        discard
    else:
      result.add(line)

  var resultNode = newIdentNode(!"result")
  for field, t in fields:
    var fieldLabel = newIdentNode(!field)
    if isSeqOfNodes(t) or isNode(t):
      var v = quote:
        `resultNode`.`fieldLabel` = `fieldLabel`
      result.add(v)

proc generateTypecheck(cases: NimNode): NimNode =
  var nodeKind = getType(NodeKind)
  var nodeNode = newIdentNode(!"node")
  var k = newIdentNode(!"kind")
  dumpTree:
    case w.kind:
    of X:
      a()
    else:
      discard
  result = buildMacro:
    caseStmt:
      dotExpr(nodeNode, k)

  for c in cases:
    assert c.kind == nnkCall and c[0].kind == nnkIdent
    var z = -1 # i am not sure why
    for n in nodeKind:
      if n.kind == nnkSym and $n == $c[0]:
        var value = generateCase(z, c[1])
        var v = buildMacro:
          ofBranch(n, value)
        result.add(v)
        break
      inc z
  var empty = newEmptyNode()
  var el = buildMacro:
    `else`:
      stmtList:
        discardStmt:
          empty
  # result.add(el)
  echo repr(result)

macro check*(cases: untyped): untyped =
  result = generateTypecheck(cases)

