import ast, env, type_env, types, errors, helpers
import tables, strutils, sequtils

type
  TripletKind* = enum TBinary, TUnary, TSave, TJump, TIf, TArg, TCall, TParam, TResult, TLabel, TInline

  Triplet* = ref object
    case kind*: TripletKind
    of TBinary:
      destination*: TripletAtom
      op*:          Operator
      left*:        TripletAtom
      right*:       TripletAtom
    of TUnary:
      z*:           TripletAtom
      unaryOp*:     Operator
      u*:           TripletAtom
    of TSave:
      value*:       TripletAtom
      target*:      TripletAtom
    of TJump:
      location*:    string
    of TIf:
      condition*:   Operator
      label*:       string
    of TArg:
      source*:      TripletAtom
      i*:           int
    of TParam:
      index*:       int
      memory*:      TripletAtom
    of TCall:
      f*:           TripletAtom
      function*:    string
      count*:       int
    of TResult:
      a*:           TripletAtom
    of TLabel:
      l*:           string
    of TInline:
      code*:        string

  TripletAtomKind* = enum ULabel, UConstant

  TripletAtom* = ref object
    triplet*: Triplet
    typ*: Type
    case kind*: TripletAtomKind
    of ULabel:
      label*: string
    of UConstant:
      node*: Node

  TripletFunction* = object
    label*:       string
    triplets*:    seq[Triplet]
    paramCount*:  int 
    locals*:      int

  TripletModule* = object
    file*:    string
    functions*: seq[TripletFunction]
    env*:     Env[int]
    temps*:   int
    labels*:  int
    predefined*: seq[Predefined]

proc render*(t: TripletAtom, depth: int): string =
  result = repeat("  ", depth)
  case t.kind:
  of ULabel:
    result.add(t.label)
  of UConstant:
    case t.node.kind:
    of AInt:
      result.add($t.node.value)
    of AString:
      result.add($t.node.s)
    of AFloat:
      result.add($t.node.f)
    of ABool:
      result.add($t.node.b)
    else:
      result.add($t.node)
  if t.kind != ULabel or t.label != "_":
    result.add(" %")
    result.add(simpleType(t.typ))

proc `$`*(t: TripletAtom): string

proc render*(triplet: Triplet, depth: int): string =
  result = repeat("  ", depth)
  var first = ""
  var second = ""
  var third = ""
  var fourth = ""
  var equal: bool
  case triplet.kind:
  of TBinary:
    first = $triplet.destination
    second = $triplet.left
    third = $triplet.op
    fourth = $triplet.right
    equal = true
  of TUnary:
    first = $triplet.z
    second = $triplet.unaryOp
    third = $triplet.u
    equal = true
  of TSave:

    first = $triplet.target
    second = $triplet.value
    equal = true
  of TJump:
    first = "JUMP"
    second = $triplet.location
    equal = false
  of TIf:
    first = "IF"
    second = $triplet.condition
    third = $triplet.label
    equal = false
  of TArg:
    first = "ARG"
    second = $triplet.source
    third = $triplet.i
    equal = false
  of TParam:
    first = "PARAM"
    second = $triplet.index
    third = $triplet.memory
    equal = false
  of TCall:
    first = $triplet.f
    second = "CALL"
    third = $triplet.function
    fourth = $triplet.count
    equal = false
  of TResult:
    first = "RESULT"
    second = $triplet.a
    equal = false
  of TLabel:
    return repeat("  ", depth - 1) & triplet.l & ":"
  of TInline:
    first = "INLINE"
    second = triplet.code[0..<10]
    equal = false
  result.add(leftAlign(first, 18, ' '))
  if equal:
    result.add("= ")
  else:
    result.add("  ")
  result.add(leftAlign(second, 20, ' '))
  if len(third) > 0:
    result.add(leftAlign(third, 10, ' '))
  if len(fourth) > 0:
    result.add(leftAlign(fourth, 10,  ' '))

proc render*(function: TripletFunction, depth: int): string =
  result = repeat("  ", depth)
  result.add(function.label)
  result.add(":\n$1" % function.triplets.mapIt(render(it, depth + 1)).join("\n"))

proc `$`*(module: TripletModule): string =
  result = "Module($1):\n$2" % [module.file, module.functions.mapIt(render(it, 1)).join("\n")]

proc `$`*(function: TripletFunction): string =
  result = render(function, 0)

proc `$`*(triplet: Triplet): string =
  result = render(triplet, 0)

proc `$`*(t: TripletAtom): string =
  result = render(t, 0)

proc uLabel*(label: string, typ: Type, triplet: Triplet = nil): TripletAtom =
  result = TripletAtom(kind: ULabel, label: label, typ: typ, triplet: triplet)
