import triplet, ast, core, types, top, env, errors
import strutils, sequtils, terminal

type
  A* = ref object of RootObj
    a*: int

  B* = ref object of A
    b*: int

proc convertFunction*(node: Node, module: var TripletModule): TripletFunction

proc convert*(ast: Node): TripletModule =
  var module = TripletModule(file: ast.name, functions: @[], env: env.newEnv[int](nil), temps: 0, labels: 0)
  if ast.kind != AProgram:
    raise newException(RoswellError, "undefined program")
  for function in ast.functions:
    module.functions.add(convertFunction(function, module))
  module.predefined = ast.predefined
  styledWriteLine(stdout, fgMagenta, "CONVERT\n", $module, resetStyle)
  result = module

template append(triplet: untyped): untyped =
  function.triplets.add(`triplet`)

proc newTemp*(module: var TripletModule, typ: Type): TripletAtom =
  if typ == voidType:
    result = uLabel("_", typ)
  else:
    result = uLabel("t$1" % $module.temps, typ)
    inc module.temps

proc activeLabel(module: var TripletModule): string =
  result = "l$1" % $(module.labels - 1)

proc newLabel(module: var TripletModule): string =
  inc module.labels
  result = activeLabel(module)

proc convertNode*(node: Node, module: var TripletModule, function: var TripletFunction): TripletAtom =
  case node.kind:
  of AGroup:
    for next in node.nodes:
      discard convertNode(next, module, function)
    result = nil
  of ACall:
    if node.function.kind == ALabel:
      var args = node.args.mapIt(convertNode(it, module, function))
      for j, arg in args:
        if arg == nil:
          raise newException(RoswellError, "arg empty")
        append Triplet(kind: TArg, source: arg, i: j)
      var f = module.newTemp(node.tag)
      if f.kind != ULabel:
        return
      append Triplet(kind: TCall, f: f, function: node.function.s, count: len(args))
      inc function.locals
      result = f
    elif node.function.kind == AOperator:
      var left = convertNode(node.args[0], module, function)
      var right = convertNode(node.args[1], module, function)
      var destination = module.newTemp(node.tag)
      var triplet = Triplet(kind: TBinary, destination: destination, op: node.function.op, left: left, right: right)
      triplet.left.triplet = triplet
      triplet.right.triplet = triplet
      append triplet
      inc function.locals
      result = destination
    else:
      raise newException(RoswellError, "corrupt node")
  of AReturn:
    var a = convertNode(node.ret, module, function)
    append Triplet(kind: TResult, a: a)
    result = nil
  of AIf:
    var test = convertNode(node.condition, module, function)
    var label = module.newLabel()
    append Triplet(kind: TIf, condition: OpNotEq, label: label)
    discard convertNode(node.success, module, function)




    if node.fail != nil:
      append Triplet(kind: TJump, location: module.newLabel())
      append Triplet(kind: TLabel, l: label)
      discard convertNode(node.fail, module, function)
      append Triplet(kind: TLabel, l: module.activeLabel())
    else:
      append Triplet(kind: TLabel, l: label)
    result = nil
  of AMember:
    raise newException(RoswellError, "unimplemented member")
  of ADefinition:
    if node.definition.kind == AAssignment:
      discard convertNode(node.definition, module, function)
    result = nil
  of AAssignment:
    var res = convertNode(node.res, module, function)
    append Triplet(kind: TSave, value: res, target: uLabel(node.target, node.res.tag))
    inc function.locals
    result = nil
  of AInt, AFloat, ABool, AString:
    result = TripletAtom(kind: UConstant, typ: node.tag, node: node)
  of ALabel:
    result = uLabel(node.s, node.tag)
  else:
    result = nil

proc convertParams(params: seq[string], types: seq[Type], module: var TripletModule, function: var TripletFunction)

proc convertFunction*(node: Node, module: var TripletModule): TripletFunction =
  if node.kind != AFunction:
    raise newException(RoswellError, "undefined function")
  if node.types.kind != Complex:
    raise newException(RoswellError, "undefined type")
  var b = B(a: 2)
  var res = TripletFunction(label: node.label, triplets: @[], paramCount: len(node.params), locals: 0)
  convertParams(node.params, node.types.args, module, res)
  discard convertNode(node.code, module, res)
  if node.label == "main":
    res.triplets.add(Triplet(kind: TInline, code: core.exitDefinition))
  result = res

proc convertParams(params: seq[string], types: seq[Type], module: var TripletModule, function: var TripletFunction) =
  for j in low(params)..high(params):
    append Triplet(kind: TParam, index: j, memory: uLabel(params[j], types[j]))
