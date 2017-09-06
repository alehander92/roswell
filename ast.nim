import core, types, type_env
import strutils, sequtils

type
  DebugFlag* = distinct bool

  Operator* = enum OpAnd, OpOr, OpEq, OpMod, OpAdd, OpSub, OpMul, OpDiv, OpNotEq, OpGt, OpGte, OpLt, OpLte, OpXor

  NodeKind* = enum AProgram, AGroup, AInt, AFloat, ABool, ACall, AFunction, ALabel, AString, APragma, AArray, AOperator, AType, AReturn, AIf, AAssignment, ADefinition, AMember, AIndex, AIndexAssignment, APointer, ADeref

  Node* = ref object of RootObj
    case kind*: NodeKind:
    of AProgram:
      name*:          string
      functions*:     seq[Node]
      predefined*:    seq[Predefined]
    of AGroup:
      nodes*:         seq[Node]
    of AInt:
      value*:         int
    of AFloat:
      f*:             float
    of ABool:
      b*:             bool
    of ACall:
      function*:      Node
      args*:          seq[Node]
    of AFunction:
      label*:         string
      params*:        seq[string]
      types*:         Type
      code*:          Node
    of ALabel, AString, APragma:
      s*:             string
    of AArray:
      elements*:      seq[Node]
    of AOperator:
      op*:            Operator
    of AType:
      typ*:           Type
    of AReturn:
      ret*:           Node
    of AIf:
      condition*:     Node
      success*:       Node
      fail*:          Node
    of AAssignment:
      target*:        string
      res*:           Node
      isDeref*:       bool
    of ADefinition:
      id*:            string
      definition*:    Node
    of AMember:
      receiver*:      Node
      member*:        string
    of AIndex:
      indexable*:     Node
      index*:         Node
    of AIndexAssignment:
      aIndex*:        Node
      aValue*:        Node
    of APointer:
      targetObject*:  Node
    of ADeref:
      derefedObject*: Node
    tag*:             Type

  NodeModule = enum MLib, MNative, MNim


let OPERATOR_SYMBOLS*: array[Operator, string] = [
  "and",  # OpAnd
  "or",   # OpOr
  "==",   # OpEq
  "%",    # OpMod
  "+",    # OpAdd
  "-",    # OpSub
  "*",    # OpMul
  "/",    # OpDiv
  "!=",   # OpNotEq
  ">",    # OpGt
  ">=",   # OpGte
  "<",    # OpLt
  "<=",   # OpLte
  "^"     # OpXor
]


proc `$`*(node: Node): string

proc render*(node: Node, depth: int): string =
  var value: string
  if node == nil:
    value = "nil"
  else:
    value = case node.kind:
    of AProgram:
      "AProgram($1):\n$2" % [$node.name, node.functions.mapIt(render(it, 1)).join("\n")]
    of AGroup:
      "AGroup:\n$1" % node.nodes.mapIt(render(it, depth + 1)).join("\n")
    of AInt:
      "AInt($1)" % $node.value
    of AFloat:
      "AFloat($1)" % $node.f
    of ABool:
      "ABool($1)" % $node.b
    of ACall:
      var typ = if node.tag == nil: "" else: " #$1" % $node.tag
      "ACall($1$2):\n$3" % [render(node.function, 0), typ, (if len(node.args) == 0: "[]" else: node.args.mapIt(render(it, depth + 1)).join("\n"))]
    of AFunction:
      "AFunction($1):\n$2params:\n$3\n$2types:\n$4\n$2code:\n$5" % [
        node.label,
        repeat("  ", depth + 1),
        node.params.mapIt(repeat("  ", depth + 2) & it).join("\n"),
        render(node.types, depth + 2),
        render(node.code, depth + 2)
      ]
    of ALabel:
      var typ = if node.tag == nil: "" else: " #$1" % $node.tag
      "ALabel($1$2)" % [node.s, typ]
    of AString:
      "AString('$1')" % node.s
    of APragma:
      "APragma($1)" % node.s
    of AArray:
      "AArray($1)" % node.elements.mapIt(render(it, depth + 1).strip(leading=true)).join(" ")
    of AOperator:
      "AOperator($1)" % $node.op
    of AType:
      "AType($1)" % $node.typ
    of AReturn:
      "AReturn($1)" % render(node.ret, depth + 1).strip(leading=true)
    of AIf:
      "AIf($1):\n$2success:\n$3\n$2fail:\n$4" % [
        render(node.condition, 0),
        repeat("  ", depth + 1),
        render(node.success, depth + 2),
        render(node.fail, depth + 2)
      ]
    of AAssignment:
      "AAssignment($1):\n$2" % [node.target, render(node.res, depth + 1)]
    of ADefinition:
      "ADefinition($1):\n$2" % [node.id, render(node.definition, depth + 1)]
    of AMember:
      "AMember($1 $2)" % [render(node.receiver, 0), node.member]
    of AIndex:
      "AIndex($1 $2)" % [render(node.indexable, depth + 1).strip(leading=true), render(node.index, 0)]
    of AIndexAssignment:
      "AIndexAssignment($1):\n$2" % [render(node.aIndex, depth + 1).strip(leading=true), render(node.aValue, depth + 1)]
    of APointer:
      "APointer($1)" % [render(node.targetObject, 0)]
    of ADeref:
      "ADeref($1)" % [render(node.derefedObject, 0)]      
    else: ""

  result = repeat("  ", depth) & value


proc `$`*(node: Node): string =
  result = render(node, 0)