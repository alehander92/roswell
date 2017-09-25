import ast, values, types, operator, top
import strutils, sequtils, tables, macros

proc toValue*(s: string): RValue

proc toValue*(s: seq[string]): RValue

proc toValue*(s: int): RValue

proc toValue*(s: seq[Node]): RValue

proc toValue*(f: float): RValue

proc toValue*(b: bool): RValue

proc toValue*(c: char): RValue

proc toValue*(op: Operator): RValue

macro toBranch(bs: varargs[untyped]): untyped =
  result = nnkStmtList.newTree(
    nnkAsgn.newTree(
      nnkDotExpr.newTree(
        newIdentNode(!"result"),
        newIdentNode(!"branch")),
      nnkPrefix.newTree(
        newIdentNode(!"@"),
        nnkBracket.newTree())))
  for x in bs:
    result[0][1][1].add(nnkCall.newTree(
      newIdentNode(!"toValue"),
      nnkDotExpr.newTree(newIdentNode(!"node"), x)))


  # stmtList:
  #   asgn:
  #     dotExpr:
  #       ident(result)
  #       ident(branch)
  #     prefix:
  #       ident("@")
  #       bracket

  # result
  #         nnkCall.newTree(
  #           nnkIdentNode(!"toValue"),
  #           nnkDotExpr.newTree(
  #             nnkIdentNode(!"node"),
  #             nnkIdentNode(!label)))))))


proc toValue*(node: Node): RValue =
  result = RValue(kind: RData, active: int(node.kind), typ: nodeType)
  case node.kind:
    of AProgram:
      toBranch(name, definitions, functions)
    of AGroup:
      toBranch(nodes)
    of ARecord:
      toBranch(rLabel, fields)
    of AEnum:
      toBranch(eLabel, variants)
    of AData:
      toBranch(dLabel, branches)
    of AField:
      toBranch(fieldLabel)
    of AInstance:
      toBranch(iLabel, iFields)
    of AIField:
      toBranch(iFieldLabel, iFieldValue)
    of AInt:
      toBranch(value)
    of AFloat:
      toBranch(f)
    of AString:
      toBranch(s)
    of ABool:
      toBranch(b)
    of AChar:
      toBranch(c)
    of ADataInstance:
      toBranch(en, enArgs)
    of ABranch:
      toBranch(bKind)
    of ACall:
      toBranch(function, args)
    of AFunction:
      toBranch(label, params, code)
    of ALabel:
      toBranch(s)
    of APragma:
      toBranch(s)
    of AOperator:
      toBranch(op)
    of AList:
      toBranch(lElements)
    of AArray:
      toBranch(elements)
    else:
      discard

proc toValue*(s: string): RValue =
  result = RValue(kind: RString, s: s, typ: stringType)

proc toValue*(s: seq[string]): RValue =
  result = RValue(kind: RList, elements: s.mapIt(toValue(it)), typ: Type(kind: Complex, label: "List", args: @[stringType]))

proc toValue*(s: int): RValue =
  result = RValue(kind: RInt, i: s, typ: intType)

proc toValue*(f: float): RValue =
  result = RValue(kind: RFloat, f: f, typ: floatType)

proc toValue*(b: bool): RValue =
  result = RValue(kind: RBool, b: b, typ: boolType)

proc toValue*(c: char): RValue =
  result = RValue(kind: RChar, c: c, typ: charType)

proc toValue*(s: seq[Node]): RValue =
  result = RValue(kind: RList, elements: s.mapIt(toValue(it)), typ: Type(kind: Complex, label: "List", args: @[]))
  result.typ.args.add(result.elements[0].typ)

proc toValue*(op: Operator): RValue =
  result = RValue(kind: REnum, e: int(op), typ: operatorType)

proc toNimString*(value: RValue): string

proc toNimSeqOfString*(value: RValue): seq[string]

proc toNimInt*(value: RValue): int

proc toNimFloat*(value: RValue): float

proc toNimBool*(value: RValue): bool

proc toNimChar*(value: RValue): char

proc toNimOperator*(value: RValue): Operator

proc toNimSeqOfNode*(value: RValue): seq[Node]

proc toNimNode*(value: RValue): Node =
  case value.kind:
  of RData:
    # echo NodeKind(value.active)
    result = case NodeKind(value.active):
      of AProgram:
        Node(kind: AProgram, name: toNimString(value.branch[0]), definitions: toNimSeqOfNode(value.branch[1]), functions: toNimSeqOfNode(value.branch[2]))
      of AGroup:
        Node(kind: AGroup, nodes: toNimSeqOfNode(value.branch[0]))
      of ARecord:
        Node(kind: ARecord, rLabel: toNimString(value.branch[0]), fields: toNimSeqOfNode(value.branch[1]))
      of AEnum:
        Node(kind: AEnum, eLabel: toNimString(value.branch[0]), variants: toNimSeqOfString(value.branch[1]))
      of AField:
        Node(kind: AField, fieldLabel: toNimString(value.branch[0]))
      of AInstance:
        Node(kind: AInstance, iLabel: toNimString(value.branch[0]), iFields: toNimSeqOfNode(value.branch[1]))
      of AIField:
        Node(kind: AIField, iFieldLabel: toNimString(value.branch[0]), iFieldValue: toNimNode(value.branch[1]))
      of AInt:
        Node(kind: AInt, value: toNimInt(value.branch[0]))
      of AEnumValue:
        Node(kind: AEnumValue, e: value.branch[0].typ.variants[toNimInt(value.branch[0])])
      of AFloat:
        Node(kind: AFloat, f: toNimFloat(value.branch[0]))
      of ABool:
        Node(kind: ABool, b: toNimBool(value.branch[0]))
      of AString:
        Node(kind: AString, s: toNimString(value.branch[0]))
      of AChar:
        Node(kind: AChar, c: toNimChar(value.branch[0]))
      of ADataInstance:
        Node(kind: ADataInstance, en: toNimString(value.branch[0]), enArgs: toNimSeqOfNode(value.branch[1]))
      of ABranch:
        Node(kind: ABranch, bKind: toNimString(value.branch[0]), bTypes: @[])
      of ACall:
        Node(kind: ACall, function: toNimNode(value.branch[0]), args: toNimSeqOfNode(value.branch[1]))
      of AFunction:
        Node(kind: AFunction, label: toNimString(value.branch[0]), params: toNimSeqOfString(value.branch[1]), code: toNimNode(value.branch[1]))
      of AIf:
        Node(kind: AIf, condition: toNimNode(value.branch[0]), success: toNimNode(value.branch[1]))
      of AForEach:
        Node(kind: AForEach, iter: toNimString(value.branch[0]), forEachIndex: toNimString(value.branch[1]), forEachSeq: toNimNode(value.branch[2]), forEachBlock: toNimNode(value.branch[3]))
      of AAssignment:
        Node(kind: AAssignment, target: toNimString(value.branch[0]), res: toNimNode(value.branch[1]), isDeref: toNimBool(value.branch[2]))
      of ADefinition:
        Node(kind: ADefinition, id: toNimString(value.branch[0]), definition: toNimNode(value.branch[1]))
      of AMember:
        Node(kind: AMember, receiver: toNimNode(value.branch[0]), member: toNimString(value.branch[1]))
      of AList:
        Node(kind: AList, lElements: toNimSeqOfNode(value.branch[0]))
      of AArray:
        Node(kind: AArray, elements: toNimSeqOfNode(value.branch[0]))
      of AOperator:
        Node(kind: AOperator, op: toNimOperator(value.branch[0]))
      of ALabel:
        Node(kind: ALabel, s: toNimString(value.branch[0]))
      else:
        nil
  else:
    result = nil


proc toNimString*(value: RValue): string =
  assert value.kind == RString
  result = value.s

proc toNimSeqOfString*(value: RValue): seq[string] =
  assert value.kind == RList
  result = value.elements.mapIt(toNimString(it))

proc toNimInt*(value: RValue): int =
  assert value.kind == RInt
  result = value.i

proc toNimFloat*(value: RValue): float =
  assert value.kind == RFloat
  result = value.f

proc toNimBool*(value: RValue): bool =
  assert value.kind == RBool
  result = value.b

proc toNimChar*(value: RValue): char =
  assert value.kind == RChar
  result = value.c
proc toNimOperator*(value: RValue): Operator =
  assert value.kind == REnum
  result = Operator(value.e)

proc toNimSeqOfNode*(value: RValue): seq[Node] =
  assert value.kind == RList
  result = value.elements.mapIt(toNimNode(it))




