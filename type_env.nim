import tables, errors
import core, types, strutils, sequtils

type
  TypeEnv*[T] = ref object
    types*:      Table[string, Type]
    functions*:  Table[string, seq[Type]]
    parent*:     TypeEnv[T]
    top*:        TypeEnv[T]
    predefined*: seq[Predefined]
    aliases*:    Table[string, T]
    enums*:      Table[string, (int, Type)]
    function*:   Type

proc getOrDefault*(t: TypeEnv, title: string): Type

proc matchOrDefault*(typeEnv: var TypeEnv, title: string, args: seq[Type]): (bool, int, Type, Table[string, Type])

proc getFunction*(t: TypeEnv, title: string): seq[Type]

proc getFunctionOrDefault*(t: TypeEnv, title: string): seq[Type]

proc `[]`*(t: TypeEnv, title: string): Type =
  result = getOrDefault(t, title)
  if result == nil:
    raise newException(RoswellError, "undefined $1" % title)
  
proc `[]=`*(t: var TypeEnv, title: string, typ: Type) =
  t.types[title] = typ

proc define*(t: var TypeEnv, title: string, typ: Type, predefined: PredefinedLabel = PNil) =
  if not t.functions.hasKey(title):
    t.functions[title] = @[]
  t.functions[title].add(typ)
  if predefined != PNil:
    t.top.predefined.add(Predefined(function: title, f: predefined, called: false))

proc match*(t: var TypeEnv, title: string, args: seq[Type]): (bool, int, Type, Table[string, Type]) =
  result = matchOrDefault(t, title, args)
  if result[2] == nil:
    raise newException(RoswellError, "undefined $1 $2" % [title, args.mapIt($it).join(",")])

proc matchOrDefault*(typeEnv: var TypeEnv, title: string, args: seq[Type]): (bool, int, Type, Table[string, Type]) =
  var t = typeEnv.getOrDefault(title)
  if t == nil:
    var functions = typeEnv.getFunctionOrDefault(title)
    if len(functions) > 0:
      for z, candidate in functions:
        if candidate.label == "Function":
          var genericArgs: seq[string] = @[]
          var callArgs: seq[Type] = @[]
          if candidate.kind == Complex:
            genericArgs = @[]
            callArgs = candidate.args[0.. < ^1]
          else:
            assert candidate.kind == Generic and candidate.complex.kind == Complex
            genericArgs = candidate.genericArgs
            callArgs = candidate.complex.args[0.. < ^1]
          var map = initTable[string, Type]()
          if unifyAll(args, callArgs, genericArgs, map):
            for predefined in typeEnv.top.predefined.mitems:
              if predefined.function == title:
                predefined.called = true
                break
            return (len(functions) == 1, z, candidate, map)
  else:
    return (true, 0, t, initTable[string, Type]())
  return (false, 0, nil, initTable[string, Type]())

proc getOrDefault*(t: TypeEnv, title: string): Type =
  var last = t
  while last != nil:
    if last.types.hasKey(title):
      return last.types[title]
    last = last.parent
  result = nil

proc getFunction*(t: TypeEnv, title: string): seq[Type] =
  var f = getFunctionOrDefault(t, title)
  if len(f) == 0:
    raise newException(RoswellError, "function undefined")

proc getFunctionOrDefault*(t: TypeEnv, title: string): seq[Type] =
  if t.top.functions.hasKey(title):
    return t.top.functions[title]
  else:
   return @[]
  
proc newEnv*[T](t: TypeEnv[T]): TypeEnv[T] =
  result = TypeEnv[T](types: initTable[string, Type](), functions: initTable[string, seq[Type]](), parent: t, predefined: @[], aliases: initTable[string, T](), enums: initTable[string, (int, Type)]())
  result.top = if t == nil: result else: t.top

proc getOrFunction*(t: TypeEnv, label: string): Type =
  result = getOrDefault(t, label)
  if result == nil:
    var results = getFunctionOrDefault(t, label)
    if len(results) == 0:
      raise newException(RoswellError, "undefined $1" % label)
    else:
      result = results[0]

proc getEnum*(t: TypeEnv, label: string): (int, Type) =
  var last = t
  while last != nil:
    if last.enums.hasKey(label):
      return last.enums[label]
    last = last.parent
  raise newException(RoswellError, "$1 undefined" % label)
