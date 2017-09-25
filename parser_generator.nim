import strutils, sequtils, tables, macros
import breeze

template newOnSuccess: untyped =
  quote:
    if success:
      discard

proc generateNode(child: NimNode): (seq[NimNode], NimNode)

proc generateManyOrSome(child: NimNode, isMany: bool): NimNode =
  var value = quote:
    while success:
      discard
  value = value[0]
  value[1].del(0)
  var s = value[1]
  var isNode = false
  for son in child:
    if son.kind == nnkStmtList:
      s.add(son)
      break
    elif isNode:
      var (newSon, newS) = generateNode(son)
      s.add(newSon)
      if newS != nil:
        s = newS
    else:
      isNode = true
  result = value

proc generateMaybe(child: NimNode): NimNode =
  result = child

proc generateNode(child: NimNode): (seq[NimNode], NimNode) =
  case child.kind:
  of nnkStrLit:
    var t = newLit($child)
    var raw = buildMacro:
      call:
        ident("raw")
        t
    result[0] = @[raw, newOnSuccess()[0]]
    result[1] = result[0][^1][^1][1]
    result[1].del(0)
    # echo "s:", treerepr(top)
  of nnkIdent:
    result[0] = @[]
    if $child == "ws":
      var raw = quote:
        left = skip(left)
      result = (@[raw[0]], nil)
    else:
      var visit = newIdentNode(!("parse$1" % capitalizeAscii($child)))
      var raw: NimNode
      if $child == "nl":
        raw = quote:
          (success, left, z) = `visit`(left, ctx, depth + 1)
      else:
        raw = quote:
          (success, left, node) = `visit`(left, ctx, depth + 1)
      result[0] = @[raw[0], newOnSuccess()[0]]
      result[1] = result[0][^1][^1][1]
      result[1].del(0)
  of nnkAccQuoted:
    result = generateNode(child[0])
  of nnkCall:
    var function = $child[0]
    case function:
    of "many", "some":
      var many = generateManyOrSome(child, function == "many")
      result = (@[many], nil)
    of "maybe":
      var maybe = generateMaybe(child)
      result = (@[maybe], nil)
    else:
      var visit = newIdentNode(!("parse$1" % capitalizeAscii($function)))
      var action = child[1]
      var a = quote:
        (success, left, node) = `visit`(left, ctx, depth + 1)
      result[0] = @[a[0]]
      var b = quote:
        if success:
          `action`
      result[0].add(b[0])
      # echo treerepr(result[0][1][0][1])
      result[1] = result[0][1][0][1]
  else:
    result = (@[], nil)

proc generateRule(e: NimNode, typ: NimNode, definition: NimNode): NimNode =
  var label = "parse$1" % capitalizeAscii($e)
  var labelNode = newIdentNode(!label)
  var f2 = newIdentNode(!"f")
  var bufferLabel = newIdentNode(!"buffer")
  var ctxLabel = newIdentNode(!"ctx")
  var depthLabel = newIdentNode(!"depth")
  var sNode = newLit(capitalizeAscii($e))
  var empty = newEmptyNode()
  var nilNode = newNilLit()
  result = quote:
    proc `labelNode`(`bufferLabel`: string, `ctxLabel`: Ctx, `depthLabel`: int = 0): (bool, string, Node) =
      testLog(`sNode`)
      var `f2` = Node(kind: `typ`, location: loc)
      decl
      left = `bufferLabel`

  var s = newStmtList()
  var top = s
  var z = 0
  for child in definition:
    if z == 0 and child.kind == nnkCall and $child[0] == "init":
      var isArg = false
      for c in child:
        if isArg:
          s.add(c)
        else:
          isArg = true
      continue
    var (sons, newS) = generateNode(child)
    for son in sons:
      s.add(son)
    if newS != nil:
      s = newS
    inc z
  var ok = buildMacro:
    returnStmt:
      par:
        ident("true")
        ident("left")
        ident("f")
  s.add(ok)
  var error = buildMacro:
    returnStmt:
      par:
        ident("false")
        ident("buffer")
        nilNode
  # echo treerepr(error)
  top.add(error)
  for son in top:
    result[0][^1].add(son)
  # echo repr(result)

macro rule*(e: untyped, typ: untyped, definition: untyped): untyped =
  result = generateRule(e, typ, definition)

