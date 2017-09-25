import ast, triplet, operator, values, errors, options, env, top
import strutils, sequtils, tables

const test = false

template evalAtom*(a: untyped): untyped {.dirty.} =
  var `a` = eval(triplet.`a`, env)

proc eval*(atom: TripletAtom, env: var Env[RValue]): RValue
proc eval*(triplet: Triplet, env: var Env[RValue], next: var string = "", function: TripletFunction, module: TripletModule, z: int): RValue
proc eval*(function: TripletFunction, args: seq[RValue], module: TripletModule, env: var Env[RValue]): RValue

proc eval*(atom: TripletAtom, env: var Env[RValue]): RValue =
  case atom.kind:
  of UInt:
    result = RValue(kind: RInt, i: atom.i, typ: intType)
  of UEnum:
    result = RValue(kind: REnum, e: atom.eValue, typ: atom.typ)
  of UFloat:
    result = RValue(kind: RFloat, f: atom.f, typ: floatType)
  of UString:
    result = RValue(kind: RString, s: atom.s, typ: stringType)
  of UBool:
    result = RValue(kind: RBool, b: atom.b, typ: boolType)
  of UChar:
    result = RValue(kind: RChar, c: atom.c, typ: charType)
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
      of OpGt:      return RValue(kind: RBool, b: left.i > right.i)
      of OpGte:     return RValue(kind: RBool, b: left.i >= right.i)
      of OpLt:      return RValue(kind: RBool, b: left.i < right.i)
      of OpLte:     return RValue(kind: RBool, b: left.i <= right.i)
      else:         return left
  of REnum:
    return constOp(op, RValue(kind: RInt, i: left.e, typ: intType), RValue(kind: RInt, i: right.e, typ: intType))
  of RString:
    case op:
      of OpAdd: return RValue(kind: RString, s: left.s & right.s)
      else:     raise newException(RoswellError, "can't $1 $2 and $3" % [$op, $left, $right])
  else:
    raise newException(RoswellError, "can't $1 $2 and $3" % [$op, $left, $right])

proc eval*(triplet: Triplet, env: var Env[RValue], next: var string = "", function: TripletFunction, module: TripletModule, z: int): RValue =
  when test:
    echo "EVAL:", triplet
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
    assert indexable.kind in {RList, RArray, RData} and iindex.kind == RInt
    if indexable.kind == RList:
      result = indexable.elements[iindex.i]
    elif indexable.kind == RArray:
      result = indexable.ar[iindex.i]
    else:
      result = indexable.branch[iindex.i]
    env[triplet.destination.label] = result
  of TList:
    result = RValue(kind: RList, elements: @[])
    env[triplet.destination.label] = result
  of TArray:
    result = RValue(kind: RArray, length: 0, cap: triplet.arrayCount, ar: @[])
    env[triplet.destination.label] = result
  of TIndexSave:
    evalAtom sIndexable
    evalAtom sIndex
    evalAtom sValue
    assert sIndexable.kind in {RList, RArray} and sIndex.kind == RInt
    if sIndexable.kind == RList and len(sIndexable.elements) - 1 < sIndex.i:
      sIndexable.elements = concat(sIndexable.elements, repeat(R_NONE, sIndex.i + 1 - len(sIndexable.elements)))
    elif sIndexable.kind == RArray and sIndexable.length - 1 < sIndex.i:
      sIndexable.ar = concat(sIndexable.ar, repeat(R_NONE, sIndex.i + 1 - sIndexable.length))
      sIndexable.length = sIndex.i + 1
    if sIndexable.kind == RList:
      sIndexable.elements[sIndex.i] = sValue
    elif sIndexable.kind == RArray:
      sIndexable.ar[sIndex.i] = sValue
    result = sValue
    env[triplet.destination.label] = result
  of TAddr:
    evalAtom addressObject
    result = RValue(kind: RAddress, address: @[addressObject])
    env[triplet.destination.label] = result
  of TDeref:
    evalAtom derefedObject
    assert derefedObject.kind == RAddress
    result = derefedObject.address[0]
    env[triplet.destination.label] = result
  of TInstance:
    var f = RValue(kind: RInstance, typ: triplet.destination.typ, fields: initTable[string, RValue]())
    result = f
    env[triplet.destination.label] = f
  of TMemberSave:
    evalAtom mValue
    var f = eval(triplet.mMember.recordObject, env)
    f.fields[triplet.mMember.recordMember] = mValue
    result = mValue
    env[triplet.destination.label] = mValue
  of TMember:
    evalAtom recordObject
    if recordObject.kind == RInstance:
      result = recordObject.fields[triplet.recordMember]
    elif recordObject.kind == RData:
      result = RValue(kind: REnum, e: recordObject.active, typ: recordObject.typ.dataKind)      
    env[triplet.destination.label] = result
  of TDataInstance:
    var f = RValue(kind: RData, active: triplet.enActive, branch: repeat(R_NONE, len(triplet.en.branches[triplet.enActive])), typ: triplet.destination.typ)
    result = f
    env[triplet.destination.label] = f
  of TDataIndex:
    evalAtom data
    assert data.kind == RData
    result = data.branch[triplet.dataIndex]
    env[triplet.destination.label] = result
  of TDataIndexSave:
    evalAtom enValue
    var f = eval(triplet.enData.data, env)
    f.branch[triplet.enData.dataIndex] = enValue
    result = enValue
    env[triplet.destination.label] = enValue
  when test:
    echo "RESULT:", result

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

proc eval*(module: TripletModule, options: Options = Options(debug: false, test: false)): RValue =
  for f in module.functions:
    if f.label == "main":
      var env = newEnv[RValue](nil)
      result = eval(f, @[], module, env)

