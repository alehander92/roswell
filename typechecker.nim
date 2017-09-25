import ast, options, type_env, operator, types, top, type_system_generator, errors
import strutils, sequtils, tables, terminal

proc typecheckNode(node: Node, env: var TypeEnv): Node

proc definitionToTypes(node: Node): seq[Type]

proc typecheckDef(def: Type, env: var TypeEnv)

proc typecheck*(ast: Node, definitions: seq[Type], env: var TypeEnv, options: Options = Options(debug: false, test: false)): (Node, seq[Type]) =
  assert ast.kind == AProgram
  var defs: seq[Type] = definitions
  # this way if b defined after a, a knows b
  for node in ast.functions:
    assert node.kind == AFunction
    env.define(node.label, node.types)
  for node in ast.definitions:
    var types = definitionToTypes(node)
    for t in types:
      env[t.label] = t
    defs = concat(defs, types)
  for def in defs:
    typecheckDef(def, env)
  for t, def in TOP_ENV.top.types:
    typecheckDef(def, env)
  var value = typecheckNode(ast, env)
  if not options.test:
    styledWriteLine(stdout, fgBlue, "TYPECHECK\n", $value, resetStyle)
  return (value, defs)

proc mangle(typ: Type): string =
  var s = simple(typ)
  for c in s:
    if isAlphaNumeric(c) or c == '_':
      result.add(toLowerAscii(c))
    else:
      result.add('_')

proc mangle(s: string, unique: bool, z: int, typ: Type): string =
  if unique:
    return s
  else:
    return "$1_$2_$3" % [s, $z, mangle(typ)]

proc typecheckDef(def: Type, env: var TypeEnv) =
  if def.kind == Data:
    assert def.dataKind.kind == Enum
    for z, variant in def.dataKind.variants:
      env.enums[variant] = (z, def)
  elif def.kind == Enum:
    for z, variant in def.variants:
      if not env.enums.hasKey(variant):
        env.enums[variant] = (z, def)
  elif def.kind == Generic and def.complex.kind == Data:
    assert def.complex.dataKind.kind == Enum
    for z, variant in def.complex.dataKind.variants:
      env.enums[variant] = (z, def)

proc definitionToTypes(node: Node): seq[Type] =
  case node.kind:
  of ARecord:
    result = @[Type(kind: Record, label: node.rLabel, fields: initTable[string, Type](), positions: initTable[string, int]())]
    for z, field in node.fields:
      assert field.kind == AField
      result[0].positions[field.fieldLabel] = z
      result[0].fields[field.fieldLabel] = field.fieldType
  of AEnum:
    result = @[Type(kind: Enum, label: node.eLabel, variants: node.variants)]
  of AData:
    result = @[Type(kind: Data, active: -1, label: node.dLabel, branches: @[])]
    var dataKind = Type(kind: Enum, label: "$1Enum" % result[0].label)
    dataKind.variants = @[]
    for branch in node.branches:
      assert branch.kind == ABranch
      dataKind.variants.add(branch.bKind)
      result[0].branches.add(branch.bTypes)
    result[0].dataKind = dataKind
    result.add(dataKind)
  else:
    result = @[]

proc typecheckCall(node: Node, env: var TypeEnv): Node

proc typecheckFunction(node: Node, env: var TypeEnv): Node

proc typecheckAssignment(node: Node, env: var TypeEnv): Node

proc typecheckDefinition(node: Node, env: var TypeEnv): Node

proc typecheckForEach(node: Node, env: var TypeEnv): Node

proc typecheckIf(node: Node, env: var TypeEnv): Node

proc typecheckIndex(node: Node, env: var TypeEnv): Node

proc typecheckReturn(node: Node, env: var TypeEnv): Node


proc typecheckNode(node: Node, env: var TypeEnv): Node =
  check:
    AProgram:
      node.predefined = env.predefined
      
      emit => voidType
    AGroup:
      emit => voidType
    ARecord:
      emit => voidType
    AEnum:
      emit => voidType
    AData:
      emit => voidType
    AField:
      emit => voidType
    AInstance:
      var iLabel = env.top[node.iLabel]

      iLabel <= Record

      for field in iFields:
        assert field.kind == AIField
        if field.iFieldLabel notin iLabel.fields or field.tag != iLabel.fields[field.iFieldLabel]:
          raise newException(RoswellError, "resolve $1" % field.iFieldLabel)

      emit => iLabel
    AIField:
      emit => iFieldValue.tag
    ADataInstance:
      var (active, en) = env.getEnum(node.en)

      var dataType: Type
      if en.kind == Data:
        dataType = en
      elif en.kind == Generic and len(en.genericArgs) == len(node.enGeneric):
        var map = initTable[string, Type]()
        for z in low(en.genericArgs)..high(en.genericArgs):
          map[en.genericArgs[z]] = node.enGeneric[z]
        dataType = mapGeneric(en, map)
      else:
        raise newException(RoswellError, "")

      enArgs <= dataType.branches[active]

      emit => Type(kind: Data, label: en.label, active: active, dataKind: en.dataKind, branches: en.branches)
    AEnumValue:
      var (active, e) = env.top.enums[node.e]

      var enumType: Type
      if e.kind == Enum:
        enumType = e
      elif e.kind == Generic and e.complex.kind == Data:
        enumType = e.complex.dataKind
      else:
        raise newException(RoswellError, "")

      node.eValue = active

      emit => enumType
    AInt:
      emit => intType
    AFloat:
      emit => floatType
    ABool:
      emit => boolType
    ALabel:
      if env.aliases.hasKey(node.s):
        result = env.aliases[node.s]
      else:
        result = Node(kind: ALabel, s: node.s, tag: env.getOrFunction(node.s), location: node.location)
    AString:
      emit => stringType
    AList:
      lElements <= @[X]

      emit => listType(X)
    AArray:
      elements <= @[X]

      emit => arrayType(X, len(elements))
    AOperator:
      emit => voidType
    AType:
      emit => voidType
    AReturn:
      return typecheckReturn(node, env)
    ACall:
      return typecheckCall(node, env)
    AFunction:
      return typecheckFunction(node, env)
    APragma:
      emit => voidType
    AChar:
      emit => charType
    AIf:
      return typecheckIf(node, env)
    AForEach:
      return typecheckForEach(node, env)
    AAssignment:
      return typecheckAssignment(node, env)
    ADefinition:
      return typecheckDefinition(node, env)
    AMember:
      var memberType: Type
      if receiver.tag.kind == Record:
        if node.member notin receiver.tag.fields:
          raise newException(RoswellError, "field $1 missing" % node.member)
        memberType = receiver.tag.fields[node.member]
      elif receiver.tag.kind == Data and node.member == "kind":
        memberType = receiver.tag.dataKind
        node.member = "active"
      else:
        raise newException(RoswellError, "invalid access")
      emit => memberType
    AIndex:
      return typecheckIndex(node, env)
    AIndexAssignment:
      aValue <= aIndex.tag

      emit => voidType
    APointer:
      emit => Type(kind: Complex, label: "Pointer", args: @[targetObject.tag])
    ADeref:
      if derefedObject.tag.kind != Complex or derefedObject.tag.label != "Pointer":
        raise newException(RoswellError, "invalid deref")

      emit => derefedObject.tag.args[0]
    ADataIndex:
      emit => voidType
    AImport:
      emit => voidType
    AMacro:
      emit => voidType
    AMacroInvocation:
      emit => voidType
    ABranch:
      emit => voidType

proc typecheckCall(node: Node, env: var TypeEnv): Node =
  var newArgs: seq[Node] = node.args.mapIt(typecheckNode(it, env))
  var tags = newArgs.mapIt(it.tag)
  var b: bool
  var i: int
  var m: Type
  var map: Table[string, Type]
  var s: string
  var newFunction: Node
  if node.function.kind == ALabel:
    (b, i, m, map) = match(env, node.function.s, tags)
    var typ = if m.kind == Complex: m else: mapGeneric(m, map)
    s = mangle(node.function.s, b, i, typ)
    newFunction = Node(kind: ALabel, s: s, location: node.location)
  elif node.function.kind == AOperator:
    if node.function.op in {OpEq, OpNotEq}: # SPECIAL
      newFunction = Node(kind: AOperator, op: node.function.op, location: node.location)
      m = functionType(concat(newArgs.mapIt(it.tag), @[boolType]), @[])
      map = initTable[string, Type]()
    else:
      s = OPERATOR_SYMBOLS[node.function.op]
      (b, i, m, map) = match(env, s, tags)
      newFunction = Node(kind: AOperator, op: node.function.op, location: node.location)
  else:
    raise newException(RoswellError, "invalid call")
  var ret: Type
  if m.kind == Complex and len(m.args) > 0:
    ret = m.args[^1]
  elif newFunction.kind == ALabel and m.kind == Generic and m.complex.kind == Complex and len(m.complex.args) > 0:
    ret = mapGeneric(m.complex.args[^1], map)
    m.instantiations.add(Instantiation(map: map, label: newFunction.s, isGeneric: env.function.kind == Generic))
    # echo m.instantiations[^1]
  else:
    raise newException(RoswellError, "invalid call $1" % $m)
  newFunction.tag = if m.kind == Complex: m else: mapGeneric(m, map)
  return Node(kind: ACall, function: newFunction, args: newArgs, tag: ret, location: node.location)

proc typecheckFunction(node: Node, env: var TypeEnv): Node =
  var functionEnv = newEnv(env)
  functionEnv.function = node.types
  if node.types.kind != Complex and node.types.kind != Generic:
    raise newException(RoswellError, "invalid function")
  else:
    var functionType = if node.types.kind == Generic: node.types.complex else: node.types
    for j, param in node.params:
      functionEnv[param] = functionType.args[j]
    if node.types.kind == Complex:
      for z, arg in node.types.args:
        if arg.kind == Data:
          for m, n in arg.dataKind.variants:
            functionEnv.enums[n] = (m, arg)
    var newCode = typecheckNode(node.code, functionEnv)
    return Node(kind: AFunction, label: node.label, params: node.params, types: node.types, code: newCode, tag: voidType, location: node.location)

      
proc typecheckForEach(node: Node, env: var TypeEnv): Node =
  if len(node.forEachIndex) > 0:
    var index = env.getOrDefault(node.forEachIndex)
    if index != nil:
      if index != intType:
        raise newException(RoswellError, "for each index $1 should be int, not $2" % [node.forEachIndex, $index])
    else:
      env[node.forEachIndex] = intType
  

  var newForEachSeq = typecheckNode(node.forEachSeq, env)
  if newForEachSeq.tag.kind != Complex or newForEachSeq.tag.label != "Array" and newForEachSeq.tag.label != "List":
    raise newException(RoswellError, "for each seq should be Array or List, not $1" % $newForEachSeq.tag)

  var iter = env.getOrDefault(node.iter)
  if iter != nil:
    if iter != newForEachSeq.tag.args[0]:
      raise newException(RoswellError, "for each iter $1 should be $2, not $3" % [node.iter, $newForEachSeq.tag.args[0], $iter])
  else:
    env[node.iter] = newForEachSeq.tag.args[0]


  var newForEachBlock = typecheckNode(node.forEachBlock, env)
  return Node(kind: AForEach, forEachIndex: node.forEachIndex, iter: node.iter, forEachSeq: newForEachSeq, forEachBlock: newForEachBlock, tag: voidType, location: node.location)




proc typecheckIf(node: Node, env: var TypeEnv): Node =
  var newCondition = typecheckNode(node.condition, env)

  var newSuccess: Node
  var newFail: Node

  # echo "if", newCondition.args[1]
  if newCondition.tag != boolType:
    raise unexpectedTypeError("if", boolType, newCondition.tag)
  elif newCondition.kind == ACall and newCondition.function.kind == AOperator and newCondition.function.op == OpNotEq and
     len(newCondition.args) == 2 and newCondition.args[1].kind == AEnumValue and newCondition.args[0].kind == AMember and
     newCondition.args[1].e == "~None" and newCondition.args[0].receiver.kind == ALabel:
    var ifEnv = env.newEnv()
    assert newCondition.args[0].receiver.tag.kind == Data
    # echo newCondition.args[0].receiver
    ifEnv[newCondition.args[0].receiver.s] = newCondition.args[0].receiver.tag
    ifEnv[newCondition.args[0].receiver.s].active = 0
    ifEnv.aliases[newCondition.args[0].receiver.s] = Node(
      kind: AIndex,
      indexable: newCondition.args[0].receiver,
      index: Node(kind: AInt, value: 0, tag: intType, location: node.location),
      tag: newCondition.args[0].receiver.tag.branches[0][0],
      location: node.location)
    newSuccess = typecheckNode(node.success, ifEnv)
    if node.fail != nil:
      newFail = typecheckNode(node.fail, ifEnv)
  else:
    newSuccess = typecheckNode(node.success, env)
    if node.fail != nil:
      newFail = typecheckNode(node.fail, env)
  return Node(kind: AIf, condition: newCondition, success: newSuccess, fail: newFail, location: node.location, tag: voidType)


proc typecheckAssignment(node: Node, env: var TypeEnv): Node =
  var newRes = typecheckNode(node.res, env)

  if newRes.tag == voidType:
    raise newException(RoswellError, "invalid assignment")
  if env.getOrDefault(node.target) == nil:
    raise newException(RoswellError, "undefined variable: $1" % node.target)
  if not node.isDeref:
    if env[node.target] != newRes.tag:
      raise unexpectedTypeError(node.target, env[node.target], newRes.tag)
  else:
    if env[node.target].kind != Complex or env[node.target].label != "Pointer" or env[node.target].args[0] != newRes.tag:
      raise unexpectedTypeError(node.target, complexType("Pointer", @[newRes.tag]), env[node.target])
  return Node(kind: AAssignment, target: node.target, res: newRes, tag: voidType, isDeref: node.isDeref, location: node.location)


proc typecheckDefinition(node: Node, env: var TypeEnv): Node =
  var newDefinition: Node
  var tag: Type
  if node.definition.kind == AAssignment:
    var newRes = typecheckNode(node.definition.res, env)
    if newRes.tag == voidType:
      raise newException(RoswellError, "invalid assignment")
    newDefinition = Node(kind: AAssignment, target: node.definition.target, res: newRes, tag: voidType, location: node.location)
    tag = newRes.tag
  elif node.definition.kind == AType:
    newDefinition = node.definition
    tag = node.definition.typ
  else:
    raise newException(RoswellError, "invalid definition")
  if env.types.hasKey(node.id):
    raise newException(RoswellError, "repeating definition: $1" % node.id)
  env[node.id] = tag
  return Node(kind: ADefinition, id: node.id, definition: newDefinition, tag: void_type, location: node.location)

proc typecheckIndex(node: Node, env: var TypeEnv): Node =
  var newIndexable = typecheckNode(node.indexable, env)
  var newIndex = typecheckNode(node.index, env)
  if (newIndexable.tag.kind != Complex or newIndexable.tag.label != "Array") and (newIndexable.tag.kind != Data or newIndexable.tag.active == -1):
    raise newException(RoswellError, "invalid indexable")
  if newIndex.tag != intType:
    raise newException(RoswellError, "invalid index")
  if newIndex.kind == AInt:
    if newIndex.value < 0:
      raise newException(RoswellError, "negative index")
    if newIndexable.tag.kind == Complex and
       newIndexable.tag.args[1].label.isDigit() and
       newIndex.value >= parseInt(newIndexable.tag.args[1].label):
      raise newException(RoswellError, "large index")
  if newIndexable.tag.kind == Complex:
    var tag = newIndexable.tag.args[0]
    return Node(kind: AIndex, indexable: newIndexable, index: newIndex, tag: tag, location: node.location)
  else:
    var branch = newIndexable.tag.branches[newIndexable.tag.active]
    if newIndex.kind == AInt and newIndex.value >= len(branch):
      raise newException(RoswellError, "large index")
    elif newIndex.kind != AInt:
      raise newException(RoswellError, "needs int")
    var tag = branch[newIndex.value]
    return Node(kind: ADataIndex, data: newIndexable, dataIndex: newIndex.value, tag: tag, location: node.location)

proc typecheckReturn(node: Node, env: var TypeEnv): Node =
  var newRet = typecheckNode(node.ret, env)
  var t = env.function
  if t.kind != Complex and t.kind != Generic or
     t.kind == Complex and len(t.args) == 0 or
     t.kind == Generic and len(t.complex.args) == 0:
    raise newException(RoswellError, "invalid function")
  elif t.kind == Complex and newRet.tag != t.args[^1] or t.kind == Generic and newRet.tag != t.complex.args[^1]:
    var ret = if t.kind == Complex: t.args[^1] else: t.complex.args[^1]
    if ret.kind == Data and ret.label == "Option" and ret.branches[0][0] == newRet.tag:
      newRet = Node(kind: ADataInstance, en: "~Ok", enArgs: @[newRet], tag: ret, location: node.location)
    else:
      raise unexpectedTypeError("return type", t.args[^1], newRet.tag)
  return Node(kind: AReturn, ret: newRet, tag: voidType, location: node.location)

# var env = newEnv(nil)
# echo typecheckNode(Node(kind: AList, lElements: @[Node(kind: AString, s: "x")]), env)
