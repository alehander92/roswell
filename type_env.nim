import tables, errors
import core, types, strutils, sequtils

type
  TypeEnv* = ref object
    types*:      Table[string, Type]
    parent*:     TypeEnv
    top*:        TypeEnv
    predefined*: seq[Predefined]
    function*:   Type

proc getOrDefault*(t: TypeEnv, title: string): Type

proc matchOrDefault*(t: var TypeEnv, title: string, args: seq[Type]): (bool, int, Type, Table[string, Type])

proc `[]`*(t: TypeEnv, title: string): Type =
  result = getOrDefault(t, title)
  if result == nil:
    raise newException(RoswellError, "undefined $1" % title)
  
proc `[]=`*(t: var TypeEnv, title: string, typ: Type) =
  t.types[title] = typ

proc define*(t: var TypeEnv, title: string, typ: Type, predefined: PredefinedLabel = PNil) =
  if t.types.hasKey(title):
    if t.types[title].kind != Overload:
      t.types[title] = Type(kind: Overload, overloads: @[])
  else:
    t.types[title] = Type(kind: Overload, overloads: @[])
  t.types[title].overloads.add(typ)
  if predefined != PNil:
    t.top.predefined.add(Predefined(function: title, f: predefined, called: false))

proc match*(t: var TypeEnv, title: string, args: seq[Type]): (bool, int, Type, Table[string, Type]) =
  result = matchOrDefault(t, title, args)
  if result[2] == nil:
    raise newException(RoswellError, "undefined $1 $2" % [title, args.mapIt($it).join(",")])

proc matchOrDefault*(t: var TypeEnv, title: string, args: seq[Type]): (bool, int, Type, Table[string, Type]) =
  var top = t.top
  if top.types.hasKey(title):
    if top.types[title].kind == Overload:
      for z, candidate in top.types[title].overloads:
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
            for predefined in top.predefined.mitems:
              if predefined.function == title:
                predefined.called = true
                break
            return (len(top.types[title].overloads) == 1, z, candidate, map)
  return (false, 0, nil, initTable[string, Type]())

proc getOrDefault*(t: TypeEnv, title: string): Type =
  var last = t
  while last != nil:
    if last.types.hasKey(title):
      return last.types[title]
    last = last.parent
  result = nil

proc newEnv*(t: TypeEnv): TypeEnv =
  result = TypeEnv(types: initTable[string, Type](), parent: t, predefined: @[])
  result.top = if t == nil: result else: t.top


