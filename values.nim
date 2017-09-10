import ast, triplet, core, types, env
import strutils, sequtils, tables

type
  
  RValueKind* = enum RInt, RFloat, RBool, RString, RNil, RFunction, RArray, RRecord, RAddress

  RValue* = ref object of RootObj
    typ*: Type
    case kind*: RValueKind
    of RInt:
      i*:        int
    of RFloat:
      f*:        float
    of RBool:
      b*:        bool
    of RString:
      s*:        string
    of RNil:
      discard
    of RFunction:
      function*: string
      instance*: TripletFunction
    of RArray:
      length*:   int
      cap*:      int
      ar*:       seq[RValue]
    of RRecord:
      fields*:   seq[RValue]
    of RAddress:
      address*:  seq[RValue]

proc `$`*(value: RValue): string =
  case value.kind:
  of RInt:
    result = $value.i
  of RFloat:
    result = $value.f
  of RBool:
    result = $value.b
  of RString:
    result = "\"$1\"" % $value.s
  of RNil:
    result = "nil"
  of RFunction:
    result = "$1 $2" % [$value.function, $value.instance.typ]
  of RArray:
    result = "_[$1]" % value.ar.mapIt($it).join(" ")
  of RRecord:
    result = $value.typ.label
  of RAddress:
    result = "address"

let R_NONE* = RValue(kind: RNil)

proc rText(args: seq[RValue], env: Env[RValue]): RValue=
  result = args[0]

proc rTextInt(args: seq[RValue], env: Env[RValue]): RValue =
  assert args[0].kind == RInt
  result = RValue(kind: RString, s: $args[0].i)

proc rTextDefault(args: seq[RValue], env: Env[RValue]): RValue =
  result = RValue(kind: RString, s: $args[0])

proc rDisplay(args: seq[RValue], env: Env[RValue]): RValue =
  case args[0].kind:
  of RString:
    echo rText(args, env)
  of RInt:
    var r = ($rTextInt(args, env))[1..^1]
    echo r
  else:
    var r = ($rTextDefault(args, env))[1..^1]
    echo r
  result = R_NONE

proc rExit(args: seq[RValue], env: Env[RValue]): RValue =
  quit(0)

proc rString(args: seq[RValue], env: Env[RValue]): RValue =
  result = R_NONE

proc rNil(args: seq[RValue], env: Env[RValue]): RValue =
  result = R_NONE

let evaluatorDefinitions* = [
  rDisplay,
  rText,
  rTextInt,
  rTextDefault,
  rExit,
  rString,
  rNil
]

let evaluatorPredefined* = {"display": PDisplayDefinition, "text_0_string": PTextDefinition, "text_1_int": PTextIntDefinition, "text_2_default": PTextDefaultDefinition, "exit": PExitDefinition}.toTable
