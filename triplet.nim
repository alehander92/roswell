import ast, env, core, type_env, types, errors, helpers
import tables, strutils, sequtils

type
  TripletKind* = enum TBinary, TUnary, TSave, TJump, TIf, TArg, TCall, TParam, TResult, TLabel, TInline, TIndex, TArray, TIndexSave, TAddr, TDeref, TInstance, TMemberSave, TMember

  Triplet* = ref object
    destination*: TripletAtom
    location*: Location
    case kind*: TripletKind
    of TBinary:
      op*:          Operator
      left*:        TripletAtom
      right*:       TripletAtom
    of TUnary:
      unaryOp*:     Operator
      u*:           TripletAtom
    of TSave:
      value*:       TripletAtom
      isDeref*:     bool
    of TJump:
      jLocation*:    string
    of TIf:
      conditionLabel*: TripletAtom
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
    of TResult: discard
    of TLabel:
      l*:           string
    of TInline:
      code*:        PredefinedLabel
    of TIndex:
      indexable*:   TripletAtom
      iindex*:      TripletAtom
    of TArray:
      arrayCount*:  int
    of TIndexSave:
      sIndexable*:  TripletAtom
      sIndex*:      TripletAtom
      sValue*:      TripletAtom
    of TAddr:
      addressObject*: TripletAtom
    of TDeref:
      derefedObject*: TripletAtom
    of TInstance:
      instanceType*: string
    of TMemberSave:
      mMember*:      Triplet
      mValue*:       TripletAtom
    of TMember:
      recordObject*: TripletAtom
      recordMember*: string

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
    typ*:         Type

  TripletModule* = object
    file*:        string
    definitions*: seq[Type]
    functions*:   seq[TripletFunction]
    env*:         Env[int]
    temps*:       int
    labels*:      int
    predefined*:  seq[Predefined]
    debug*:       bool

proc render*(t: TripletAtom, depth: int): string =
  if t == nil:
    result = "nil"
    return
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
    result.add(simple(t.typ))

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
    first = $triplet.destination
    second = $triplet.unaryOp
    third = $triplet.u
    equal = true
  of TSave:

    first = $triplet.destination
    second = $triplet.value
    equal = true
  of TJump:
    first = "JUMP"
    second = $triplet.jLocation
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
    second = $triplet.destination
    equal = false
  of TLabel:
    return repeat("  ", depth - 1) & triplet.l & ":"
  of TInline:
    first = "INLINE"
    second = $triplet.code
    equal = false
  of TIndex:
    first = $triplet.destination
    second = "INDEX"
    third = $triplet.indexable
    fourth = $triplet.iindex
    equal = true
  of TArray:
    first = $triplet.destination
    second = "ARRAY"
    third = $triplet.arrayCount
    equal = true
  of TIndexSave:
    first = $triplet.destination
    second = $triplet.sIndexable
    third = $triplet.sIndex
    fourth = $triplet.sValue
    equal = true
  of TAddr:
    first = $triplet.destination
    second = "ADDRESS"
    third = $triplet.addressObject
    equal = true
  of TDeref:
    first = $triplet.destination
    second = "DEREF"
    third = $triplet.derefedObject
    equal = true
  of TInstance:
    first = $triplet.destination
    second = "INSTANCE"
    third = triplet.instanceType
    equal = true
  of TMemberSave:
    first = $triplet.destination
    second = $triplet.mMember.recordObject
    third = triplet.mMember.recordMember
    fourth = $triplet.mValue
    equal = true
  of TMember:
    first = $triplet.destination
    second = "MEMBER"
    third = $triplet.recordObject
    fourth = triplet.recordMember
    equal = true
  result.add(leftAlign(first, 18, ' '))
  if equal:
    result.add("= ")
  else:
    result.add("  ")
  result.add(leftAlign(second, 20, ' '))
  result.add(leftAlign(third, 10, ' '))
  result.add(leftAlign(fourth, 10,  ' '))
  result.add(leftAlign($triplet.location, 10, ' '))

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

proc ss(s: int): int =
  result = 2
