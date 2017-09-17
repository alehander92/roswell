import triplet, ast, core, types, top, env, errors
import strutils, sequtils, terminal

type
  A* = ref object of RootObj
    a*: int

  B* = ref object of A
    b*: int

proc convertFunction*(node: Node, module: var TripletModule): TripletFunction

proc convert*(ast: Node, definitions: seq[Type], debug: bool=false): TripletModule =
  var module = TripletModule(file: ast.name, definitions: definitions, functions: @[], env: env.newEnv[int](nil), temps: 0, labels: 0, debug: debug)
  if ast.kind != AProgram:
    raise newException(RoswellError, "undefined program")
  for function in ast.functions:
    module.functions.add(convertFunction(function, module))
  module.predefined = ast.predefined
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
  of AInstance:
    var instance = module.newTemp(node.tag)
    append Triplet(kind: TInstance, instanceType: node.iLabel, destination: instance, location: node.location)
    for field in node.iFields:
      assert field.kind == AIField
      var mValue = convertNode(field.iFieldValue, module, function)
      var destination = module.newTemp(field.tag)
      append Triplet(kind: TMemberSave, mMember: Triplet(kind: TMember, recordObject: instance, recordMember: field.iFieldLabel), mValue: mValue, destination: destination, location: node.location)
    result = instance      
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
        append Triplet(kind: TArg, source: arg, i: j, location: node.args[j].location)
      var f = module.newTemp(node.tag)
      if f.kind != ULabel:
        return
      append Triplet(kind: TCall, f: f, function: node.function.s, count: len(args), location: node.location)
      inc function.locals
      result = f
    elif node.function.kind == AOperator:
      var left = convertNode(node.args[0], module, function)
      var right = convertNode(node.args[1], module, function)
      var destination = module.newTemp(node.tag)
      var triplet = Triplet(kind: TBinary, destination: destination, op: node.function.op, left: left, right: right, location: node.location)
      triplet.left.triplet = triplet
      triplet.right.triplet = triplet
      append triplet
      inc function.locals
      result = destination
    else:
      raise newException(RoswellError, "corrupt node")
  of AReturn:
    var a = convertNode(node.ret, module, function)
    append Triplet(kind: TResult, destination: a, location: node.location)
    result = nil
  of AIf:
    var test = convertNode(node.condition, module, function)
    var label = module.newLabel()
    append Triplet(kind: TIf, conditionLabel: test, condition: OpNotEq, label: label, location: node.location)
    discard convertNode(node.success, module, function)




    if node.fail != nil:
      append Triplet(kind: TJump, jLocation: module.newLabel(), location: node.fail.location)
      append Triplet(kind: TLabel, l: label, location: node.fail.location)
      discard convertNode(node.fail, module, function)
      append Triplet(kind: TLabel, l: module.activeLabel(), location: node.fail.location)
    else:
      append Triplet(kind: TLabel, l: label, location: node.location)
    result = nil
  of AForEach:
    var index = if len(node.forEachIndex) > 0: uLabel(node.forEachIndex, intType) else: module.newTemp(intType)
    append Triplet(kind: TSave, value: TripletAtom(kind: UConstant, node: Node(kind: AInt, value: 0)), destination: index, isDeref: false, location: node.location)
    var label = module.newLabel()
    var endLabel = module.newLabel()
    append Triplet(kind: TLabel, l: label, location: node.location)
    assert node.forEachSeq.tag.kind == Complex and node.forEachSeq.tag.label == "Array"
    var limit = parseInt(node.forEachSeq.tag.args[1].label)
    var test = module.newTemp(boolType)
    append Triplet(kind: TBinary, op: OpLt, left: index, right: TripletAtom(kind: UConstant, node: Node(kind: AInt, value: limit)), destination: test, location: node.location)
    append Triplet(kind: TIf, conditionLabel: test, condition: OpNotEq, label: endLabel)    
    var forEachSeq = convertNode(node.forEachSeq, module, function)
    var iter = uLabel(node.iter, node.forEachSeq.tag.args[0])
    append Triplet(kind: TIndex, indexable: forEachSeq, iindex: index, destination: iter, location: node.location)
    discard convertNode(node.forEachBlock, module, function)
    append Triplet(kind: TBinary, op: OpAdd, left: index, right: TripletAtom(kind: UConstant, node: Node(kind: AInt, value: 1)), destination: index, location: node.location)
    append Triplet(kind: TJump, jLocation: label, location: node.location)
    append Triplet(kind: TLabel, l: endLabel, location: node.forEachBlock.nodes[^1].location)
  of AMember:
    var destination = module.newTemp(node.tag)
    var receiver = convertNode(node.receiver, module, function)
    append Triplet(kind: TMember, recordObject: receiver, recordMember: node.member, destination: destination)
    result = destination
  of ADefinition:
    if node.definition.kind == AAssignment:
      discard convertNode(node.definition, module, function)
    result = nil
  of AAssignment:
    var res = convertNode(node.res, module, function)
    append Triplet(kind: TSave, value: res, destination: uLabel(node.target, node.res.tag), isDeref: node.isDeref, location: node.location)
    inc function.locals
    result = nil
  of AInt, AFloat, ABool, AString:
    result = TripletAtom(kind: UConstant, typ: node.tag, node: node)
  of ALabel:
    result = uLabel(node.s, node.tag)
  of AIndex:
    # the address by offset
    var indexable = convertNode(node.indexable, module, function)
    var index = convertNode(node.index, module, function)
    var destination = module.newTemp(node.tag)
    append Triplet(kind: TIndex, indexable: indexable, iindex: index, destination: destination, location: node.location)
    result = destination
  of AArray:
    var destination = module.newTemp(node.tag)
    if destination.kind != ULabel:
      return
    append Triplet(kind: TArray, arrayCount: len(node.elements), destination: destination, location: node.location)
    for j, element in node.elements:
      discard convertNode(Node(kind: AIndexAssignment, aIndex: Node(kind: AIndex, indexable: Node(kind: ALabel, s: destination.label, tag: node.tag), index: Node(kind: AInt, value: j, tag: intType), tag: node.elements[0].tag), aValue: element, tag: voidType), module, function)
    result = destination
  of AIndexAssignment:
    # AIndexAssignment(aIndex: AIndex(@indexable, @index), @aValue) -> Triplet(TIndexSave, $newTemp, !@indexable, !@index, !@aValue)
    if node.aIndex.kind != AIndex:
      raise newException(RoswellError, "invalid node")
    var sIndexable = convertNode(node.aIndex.indexable, module, function)
    var sIndex = convertNode(node.aIndex.index, module, function)
    var sValue = convertNode(node.aValue, module, function)
    var destination = module.newTemp(node.aValue.tag)
    append Triplet(kind: TIndexSave, destination: destination, sIndexable: sIndexable, sIndex: sIndex, sValue: sValue, location: node.location)
    result = destination
  of APointer:
    var destination = module.newTemp(node.tag)
    var addressObject = convertNode(node.targetObject, module, function)
    append Triplet(kind: TAddr, destination: destination, addressObject: addressObject, location: node.location)
    result = destination
  of ADeref:
    var destination = module.newTemp(node.tag)
    var derefedObject = convertNode(node.derefedObject, module, function)
    append Triplet(kind: TDeref, destination: destination, derefedObject: derefedObject, location: node.location)
    result = destination
  else:
    result = nil
  
proc convertParams(params: seq[string], types: seq[Type], module: var TripletModule, function: var TripletFunction, location: Location)

proc convertFunction*(node: Node, module: var TripletModule): TripletFunction =
  if node.kind != AFunction:
    raise newException(RoswellError, "undefined function")
  if node.types.kind != Complex:
    raise newException(RoswellError, "undefined type")
  var b = B(a: 2)
  var res = TripletFunction(label: node.label, triplets: @[], paramCount: len(node.params), locals: 0, typ: node.types)
  convertParams(node.params, node.types.args, module, res, node.location)
  discard convertNode(node.code, module, res)
  if node.label == "main":
    res.triplets.add(Triplet(kind: TInline, code: core.PExitDefinition, location: node.location))
  result = res

proc convertParams(params: seq[string], types: seq[Type], module: var TripletModule, function: var TripletFunction, location: Location) =
  for j in low(params)..high(params):
    append Triplet(kind: TParam, index: j, memory: uLabel(params[j], types[j]), location: location)
