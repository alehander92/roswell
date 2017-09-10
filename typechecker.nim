import ast, type_env, types, top, errors
import strutils, sequtils, tables, terminal

proc typecheckNode(node: Node, env: var TypeEnv): Node

proc typecheck*(ast: Node, env: var TypeEnv): Node =
  if ast.kind != AProgram:
    raise newException(RoswellError, "undefined program")
  # this way if b defined after a, a knows b
  for node in ast.functions:
    if node.kind != AFunction:
      raise newException(RoswellError, "undefined program")
    env.define(node.label, node.types)
  var value = typecheckNode(ast, env)
  styledWriteLine(stdout, fgBlue, "TYPECHECK\n", $value, resetStyle)
  return value

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

proc typecheckNode(node: Node, env: var TypeEnv): Node =
  case node.kind:
  of AProgram:
    var newFunctions: seq[Node] = node.functions.mapIt(typecheckNode(it, env))
    return Node(kind: AProgram, name: node.name, functions: newFunctions, predefined: env.predefined, location: node.location)
  of AGroup:
    var newNodes: seq[Node] = node.nodes.mapIt(typecheckNode(it, env))
    return Node(kind: AGroup, nodes: newNodes, location: node.location)
  of AInt:
    return Node(kind: AInt, value: node.value, tag: intType, location: node.location)
  of AFloat:
    return Node(kind: AFloat, f: node.f, tag: Type(kind: Simple, label: "Float"), location: node.location)
  of ABool:
    return Node(kind: ABool, b: node.b, tag: boolType, location: node.location)
  of ACall:
    var newArgs: seq[Node] = node.args.mapIt(typecheckNode(it, env))
    var tags = newArgs.mapIt(it.tag)
    # for now labels
    var b: bool
    var i: int
    var m: Type
    var map: Table[string, Type]
    var s: string
    var newFunction: Node
    if node.function.kind == ALabel:
      (b, i, m, map) = match(env, node.function.s, tags)
      s = mangle(node.function.s, b, i, m)
      newFunction = Node(kind: ALabel, s: s, location: node.location)
    elif node.function.kind == AOperator:
      s = OPERATOR_SYMBOLS[node.function.op]
      (b, i, m, map) = match(env, s, tags)
      newFunction = Node(kind: AOperator, op: node.function.op, location: node.location)
    else:
      raise newException(RoswellError, "invalid call")
    var ret: Type
    if m.kind == Complex and len(m.args) > 0:
      ret = m.args[^1]
    elif m.kind == Generic and m.complex.kind == Complex and len(m.complex.args) > 0:
      ret = mapGeneric(m.complex.args[^1], map)
    else:
      raise newException(RoswellError, "invalid call $1" % $m)
    newFunction.tag = m
    return Node(kind: ACall, function: newFunction, args: newArgs, tag: ret, location: node.location)
  of AFunction:
    var functionEnv = newEnv(env)
    functionEnv.function = node.types
    if node.types.kind != Complex:
      raise newException(RoswellError, "invalid function")
    else:
      for j, param in node.params:
        functionEnv[param] = node.types.args[j]
      var newCode = typecheckNode(node.code, functionEnv)
      return Node(kind: AFunction, label: node.label, params: node.params, types: node.types, code: newCode, tag: voidType, location: node.location)
  of ALabel:
    return Node(kind: ALabel, s: node.s, tag: env[node.s], location: node.location)
  of AString:
    return Node(kind: AString, s: node.s, tag: stringType, location: node.location)
  of APragma:
    return Node(kind: APragma, s: node.s, tag: voidType, location: node.location)
  of AArray:
    if len(node.elements) < 1:
      raise newException(RoswellError, "empty array")
    var elementTag: Type
    var newElements: seq[Node] = @[]
    for element in node.elements:
      var newElement = typecheckNode(element, env)
      if elementTag == nil:
        elementTag = newElement.tag
      else:
        if newElement.tag != elementTag:
          raise newException(RoswellError, "array expected $1 not $2" % [$elementTag, $newElement.tag])
      newElements.add(newElement)
    return Node(kind: AArray, elements: newElements, tag: Type(kind: Complex, label: "Array", args: @[elementTag, Type(kind: Simple, label: $len(newElements))]), location: node.location)
  of AOperator:
    return Node(kind: AOperator, op: node.op, tag: voidType, location: node.location)
  of AType:
    return Node(kind: AType, typ: node.typ, tag: voidType, location: node.location)
  of AReturn:
    var newRet = typecheckNode(node.ret, env)
    var t = env.function
    if t.kind != Complex or len(t.args) == 0:
      raise newException(RoswellError, "invalid function")
    elif newRet.tag != t.args[^1]:
      raise newException(RoswellError, "return type expected: $1, not $2" % [$t.args[^1], $newRet.tag])
    return Node(kind: AReturn, ret: newRet, tag: voidType, location: node.location)
  of AIf:
    # AIf(!condition: #boolType, !success, !fail) -> #voidType
    var newCondition = typecheckNode(node.condition, env)

    if newCondition.tag != boolType:
      raise newException(RoswellError, "invalid if")
    var newSuccess = typecheckNode(node.success, env)
    var newFail: Node
    if node.fail == nil:
      newFail = nil
    else:
      newFail = typecheckNode(node.fail, env)
    return Node(kind: AIf, condition: newCondition, success: newSuccess, fail: newFail, tag: voidType, location: node.location)
  of AAssignment:
    var newRes = typecheckNode(node.res, env)

    if newRes.tag == voidType:
      raise newException(RoswellError, "invalid assignment")
    if not env.types.hasKey(node.target):
      raise newException(RoswellError, "undefined variable: $1" % node.target)
    if not node.isDeref:
      if env[node.target] != newRes.tag:
        raise newException(RoswellError, "$1: expected $2, not $3" % [node.target, simple(env[node.target]), simple(newRes.tag)])
    else:
      if env[node.target].kind != Complex or env[node.target].label != "Pointer" or env[node.target].args[0] != newRes.tag:
        raise newException(RoswellError, "$1: expected a Pointer[$2], not $3" % [node.target, simple(newRes.tag), simple(env[node.target])])
    return Node(kind: AAssignment, target: node.target, res: newRes, tag: voidType, isDeref: node.isDeref, location: node.location)
  of ADefinition:
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
  of AMember:
    var newReceiver = typecheckNode(node.receiver, env)
    raise newException(RoswellError, "feature is missing")
  of AIndex:
    var newIndexable = typecheckNode(node.indexable, env)
    var newIndex = typecheckNode(node.index, env)
    if newIndexable.tag.kind != Complex or newIndexable.tag.label != "Array":
      raise newException(RoswellError, "invalid indexable")
    if newIndex.tag != intType:
      raise newException(RoswellError, "invalid index")
    if newIndex.kind == AInt:
      if newIndex.value < 0:
        raise newException(RoswellError, "negative index")
      if newIndex.value >= parseInt(newIndexable.tag.args[1].label):
        raise newException(RoswellError, "large index")
    var tag = newIndexable.tag.args[0]
    return Node(kind: AIndex, indexable: newIndexable, index: newIndex, tag: tag, location: node.location)
  of AIndexAssignment:
    var newAIndex = typecheckNode(node.aIndex, env)
    var newAValue = typecheckNode(node.aValue, env)
    if newAValue.tag != newAIndex.tag:
      raise newException(RoswellError, "invalid operation")
    return Node(kind: AIndexAssignment, aIndex: newAIndex, aValue: newAValue, tag: voidType, location: node.location)
  of APointer:
    var newTargetObject = typecheckNode(node.targetObject, env)
    var tag = Type(kind: Complex, label: "Pointer", args: @[newTargetObject.tag])
    return Node(kind: APointer, targetObject: newTargetObject, tag: tag, location: node.location)
  of ADeref:
    var newDerefedObject = typecheckNode(node.derefedObject, env)
    if newDerefedObject.tag.kind != Complex or newDerefedObject.tag.label != "Pointer":
      raise newException(RoswellError, "invalid deref")
    return Node(kind: ADeref, derefedObject: newDerefedObject, tag: newDerefedObject.tag.args[0], location: node.location)
  return node


