import ast, triplet, values, errors, env
import strutils, sequtils, tables

template evalAtom*(a: untyped): untyped {.dirty.} =
  var `a` = eval(triplet.`a`, env)

proc eval*(atom: TripletAtom, env: var Env[RValue]): RValue
proc eval*(triplet: Triplet, env: var Env[RValue], next: var string = "", function: TripletFunction, module: TripletModule, z: int): RValue
proc eval*(function: TripletFunction, args: seq[RValue], module: TripletModule, env: var Env[RValue]): RValue

proc eval*(atom: TripletAtom, env: var Env[RValue]): RValue =
  case atom.kind:
  of UConstant:
    case atom.node.kind:
    of AInt:
      result = RValue(kind: RInt, i: atom.node.value)
    of AFloat:
      result = RValue(kind: RFloat, f: atom.node.f)
    of AString:
      result = RValue(kind: RString, s: atom.node.s)
    of ABool:
      result = RValue(kind: RBool, b: atom.node.b)
    else:
      result = nil
  of ULabel:
    result = env[atom.label]

proc constOp(op: Operator, left: RValue, right: RValue): RValue =
  if left.kind != right.kind:
    raise newException(RoswellError, "can't $1 $2 and $3" % [$op, $left, $right])
  case left.kind:
  of RBool:
    case op:
      of OpAnd:     return RValue(kind: RBool, b: left.b and right.b)
      of OpOr:      return RValue(kind: RBool, b: left.b or right.b)
      of OpXor:     return RValue(kind: RBool, b: left.b xor right.b)
      of OpEq:      return RValue(kind: RBool, b: left.b == right.b)
      of OpNotEq:   return RValue(kind: RBool, b: left.b != right.b)
      else:         return left
  of RInt:
    case op:
      of OpAdd:     return RValue(kind: RInt,  i: left.i + right.i)
      of OpSub:     return RValue(kind: RInt,  i: left.i - right.i)
      of OpMul:     return RValue(kind: RInt,  i: left.i * right.i)
      of OpDiv:     return RValue(kind: RInt,  i: left.i div right.i)
      of OpMod:     return RValue(kind: RInt,  i: left.i mod right.i)
      of OpEq:      return RValue(kind: RBool, b: left.i == right.i)
      of OpNotEq:   return RValue(kind: RBool, b: left.i != right.i)
      else:         return left
  of RString:
    case op:
      of OpAdd: return RValue(kind: RString, s: left.s & right.s)
      else:     raise newException(RoswellError, "can't $1 $2 and $3" % [$op, $left, $right])
  else:
    raise newException(RoswellError, "can't $1 $2 and $3" % [$op, $left, $right])

proc eval*(triplet: Triplet, env: var Env[RValue], next: var string = "", function: TripletFunction, module: TripletModule, z: int): RValue =
  case triplet.kind:
  of TBinary:
    evalAtom left
    evalAtom right
    result = constOp(triplet.op, left, right)
    env[triplet.destination.label] = result
  of TUnary:
    raise newException(RoswellError, "undefined $1" % $triplet.kind)
  of TSave:
    evalAtom value
    result = value
    env[triplet.destination.label] = result
  of TJump:
    next.add(triplet.jLocation)
    result = R_NONE
  of TIf:
    evalAtom conditionLabel
    var test = constOp(triplet.condition, conditionLabel, RValue(kind: RBool, b: true))
    if test.kind == RBool and test.b:
      next.add(triplet.label)
    result = R_NONE
  of TArg:
    result = R_NONE
  of TParam:
    result = R_NONE
  of TCall:
    var args: seq[RValue] = @[]
    for v, arg in function.triplets[z - triplet.count..z-1]:
      args.add(eval(arg.source, env))
    if evaluatorPredefined.hasKey(triplet.function):
      result = evaluatorDefinitions[int(evaluatorPredefined[triplet.function])](args, env)
    else:
      for f in module.functions:
        if f.label == triplet.function:
          result = eval(f, args, module, env)
    env[triplet.f.label] = result
  of TResult:
    evalAtom destination
    result = destination
  of TLabel:
    result = R_NONE
  of TInline:
    result = R_NONE
  of TIndex:
    evalAtom indexable
    evalAtom iindex
    assert indexable.kind == RArray and iindex.kind == RInt
    result = indexable.ar[iindex.i]
    env[triplet.destination.label] = result
  of TArray:
    result = RValue(kind: RArray, length: 0, cap: triplet.arrayCount, ar: @[])
    env[triplet.destination.label] = result
  of TIndexSave:
    evalAtom sIndexable
    evalAtom sIndex
    evalAtom sValue
    assert sIndexable.kind == RArray and sIndex.kind == RInt
    if sIndexable.length - 1 < sIndex.i:
      sIndexable.ar = concat(sIndexable.ar, repeat(R_NONE, sIndex.i + 1 - sIndexable.length))
      sIndexable.length = sIndex.i + 1
    sIndexable.ar[sIndex.i] = sValue
    result = sValue
  of TAddr:
    evalAtom addressObject
    result = RValue(kind: RAddress, address: @[addressObject])
    env[triplet.destination.label] = result
  of TDeref:
    evalAtom derefedObject
    assert derefedObject.kind == RAddress
    result = derefedObject.address[0]
    env[triplet.destination.label] = result

proc eval*(function: TripletFunction, args: seq[RValue], module: TripletModule, env: var Env[RValue]): RValue =
  var functionEnv = newEnv[RValue](env)
  for z in 0..<function.paramCount:
    assert function.triplets[z].kind == TParam and function.triplets[z].memory.kind == ULabel
    functionEnv[function.triplets[z].memory.label] = args[z]
  var z = function.paramCount
  var map = initTable[string, int]()
  for z, triplet in function.triplets:
    if triplet.kind == TLabel:
      map[triplet.l] = z
  var value = R_NONE
  while z < len(function.triplets):
    var triplet = function.triplets[z]
    var next = ""
    value = eval(function.triplets[z], functionEnv, next, function, module, z)
    if triplet.kind == TResult:
      return value
    elif len(next) > 0:
      z = map[next]
    else:
      inc z
  return value

proc eval*(module: TripletModule): RValue =
  for f in module.functions:
    if f.label == "main":
      var env = newEnv[RValue](nil)
      result = eval(f, @[], module, env)

