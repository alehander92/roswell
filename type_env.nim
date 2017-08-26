import tables, errors
import types, strutils, sequtils

type
  TypeEnv* = ref object
    types*:      Table[string, Type]
    parent*:     TypeEnv
    top*:        TypeEnv
    predefined*: seq[Predefined]

  Predefined* = object
    function*:  string
    code*:      string
    called*:    bool

proc getOrDefault*(t: TypeEnv, title: string): Type

proc matchOrDefault*(t: var TypeEnv, title: string, args: seq[Type]): Type

proc `[]`*(t: TypeEnv, title: string): Type =
  result = getOrDefault(t, title)
  if result == nil:
    raise newException(RoswellError, "undefined $1" % title)
  
proc `[]=`*(t: var TypeEnv, title: string, typ: Type) =
  t.types[title] = typ

proc define*(t: var TypeEnv, title: string, typ: Type, predefined: string = "") =
  if t.types.hasKey(title):
    if t.types[title].kind != Overload:
      t.types[title] = Type(kind: Overload, overloads: @[])
  else:
    t.types[title] = Type(kind: Overload, overloads: @[])
  t.types[title].overloads.add(typ)
  if len(predefined) > 0:
    t.top.predefined.add(Predefined(function: title, code: predefined, called: false))

proc match*(t: var TypeEnv, title: string, args: seq[Type]): Type =
  result = matchOrDefault(t, title, args)
  if result == nil:
    raise newException(RoswellError, "undefined $1 $2" % [title, args.mapIt($it).join(",")])

proc matchOrDefault*(t: var TypeEnv, title: string, args: seq[Type]): Type =
  var top = t.top
  if top.types.hasKey(title):
    if top.types[title].kind == Overload:
      for candidate in top.types[title].overloads:
        if candidate.kind == Complex and candidate.label == "Function":
          if allZip(args, candidate.args[0.. < ^1]):
            for predefined in top.predefined.mitems:
              if predefined.function == title:
                predefined.called = true
                break
            return candidate
  return nil

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


