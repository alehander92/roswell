import ast, values, types, top
import strutils, sequtils, tables, macros

proc toValue*(s: string): RValue

proc toValue*(s: seq[string]): RValue

proc toValue*(s: int): RValue

proc toValue*(s: seq[Node]): RValue

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
  result = RValue(kind: RData, active: int(node.kind))
  case node.kind:
    of AProgram:
      toBranch(name, definitions, functions)
    of AGroup:
      toBranch(nodes)
    of ARecord:
      toBranch(rLabel, fields)
    of AEnum:
      toBranch(eLabel, variants)
    of AField:
      toBranch(fieldLabel)
    of AInstance:
      toBranch(iLabel, iFields)
    of AIField:
      toBranch(iFieldLabel, iFieldValue)
    of AInt:
      toBranch(value)
    else:
      discard

proc toValue*(s: string): RValue =
  result = RValue(kind: RString, s: s, typ: stringType)

proc toValue*(s: seq[string]): RValue =
  result = RValue(kind: RList, elements: s.mapIt(toValue(it)), typ: Type(kind: Complex, label: "List", args: @[stringType]))

proc toValue*(s: int): RValue =
  result = RValue(kind: RInt, i: s, typ: intType)

proc toValue*(s: seq[Node]): RValue =
  result = RValue(kind: RList, elements: s.mapIt(toValue(it)), typ: Type(kind: Complex, label: "List", args: @[]))
  result.typ.args.add(result.elements[0].typ)

proc toNimString*(value: RValue): string

proc toNimSeqOfString*(value: RValue): seq[string]

proc toNimInt*(value: RValue): int

proc toNimSeqOfNode*(value: RValue): seq[Node]

proc toNimNode*(value: RValue): Node =
  case value.kind:
  of RData:
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

proc toNimSeqOfNode*(value: RValue): seq[Node] =
  assert value.kind == RList
  result = value.elements.mapIt(toNimNode(it))




