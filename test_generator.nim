import ast, types, top, breeze
import random, strutils, sequtils, tables, macros

proc generateFunction(label: string): Node

proc generateAst*: Node =
  var f = random(8)
  var functions: seq[Node] = @[]
  for z in 0..<f:
    functions.add(generateFunction("f$1" % $z))
  result = Node(kind: AProgram, imports: @[], definitions: @[], predefined: @[], functions: functions)

proc randomLabel(title: bool = false): string =
  var letter = random(26)
  var l = random(5)
  result = " "
  result[0] = if not title: char(letter + int('a')) else: char(letter + int('A'))
  for z in 0..<l:
    var symbol = random(52)
    if symbol < 26:
      result.add(char(int('a') + symbol))
    else:
      result.add(char(int('A') + (symbol - 26)))


macro genType(): untyped =
  var kind = TypeKind(random(7))
  var t = getType(BType)
  assert t.kind == nnkObjectTy
  var typeLabel = newLit(randomLabel(title=true))
  var kindLabel = newIdentNode($kind)
  result = buildMacro:
    objConstr:
      ident("Type")
      exprColonExpr:
        ident("kind")
        kindLabel
      exprColonExpr:
        ident("label")
        typeLabel

  for branch in t[2][1]:
    if branch.kind != nnkSym:
      echo int(kind), parseInt(treerepr(branch[0]).split(' ')[1])
      if int(kind) == parseInt(treerepr(branch[0]).split(' ')[1]):
        echo treerepr(branch[1])
  echo treerepr(t)

proc generateType*: Type =
  result = genType()

proc generateFunction(label: string): Node =
  var p = random(8)
  var params: seq[string] = @[]
  var types = functionType(@[], @[])
  assert types.kind == Complex
  for z in 0..<p:
    params.add("l$1" % $z)
    types.args.add(generateType())
  types.args.add(generateType())

  result = Node(kind: AFunction, label: label, params: params, types: types)
