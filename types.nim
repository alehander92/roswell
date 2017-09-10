import strutils, sequtils, tables

type
  TypeKind* = enum Simple, Complex, Generic, Overload, Default, Record

  Type* = ref object
    label*: string
    case kind*: TypeKind
    of Simple: discard
    of Complex:
      args*: seq[Type]
    of Generic:
      genericArgs*: seq[string]
      complex*: Type
      instantiations*: seq[Type]
    of Overload:
      overloads*: seq[Type]
    of Default: discard # for display/text: if no other types are matched, this works
    of Record:
      fields*: Table[string, Type]
      positions*: Table[string, int]

const Function* = "Function"

proc `$`*(typ: Type): string

proc render*(typ: Type, depth: int): string =
  var value = ""
  if typ == nil:
    value = "nil"
  else:
    value = case typ.kind:
    of Simple:
      "Simple{$1}" % typ.label
    of Complex:
      "Complex{$1, $2}" % [typ.label, typ.args.mapIt($it).join(" ")]
    of Generic:
      "Generic{$1, $2, $3}" % [typ.label, typ.genericArgs.mapIt($it).join(" "), $typ.complex]
    of Overload:
      "Overload{$1, $2}" % [if typ.label != nil: typ.label else: "", typ.overloads.mapIt($it).join("  ")]
    of Default:
      "Default" 
    of Record:
      "Record{$1}" % typ.label
  result = repeat("  ", depth) & value

proc `$`*(typ: Type): string =
  result = render(typ, 0)
  
proc functionType*(args: seq[Type], genericArgs: seq[string] = @[]): Type =
  if len(genericArgs) == 0:
    result = Type(kind: Complex, label: Function, args: args)
  else:
    result = Type(kind: Generic, label: Function, genericArgs: genericArgs, complex: Type(kind: Complex, label: Function, args: args))

proc simpleType*(label: string): Type =
  result = Type(kind: Simple, label: label)

proc complexType*(label: string, args: varargs[Type]): Type =
  result = Type(kind: Complex, label: label, args: @args)

proc unifyAll*(a: seq[Type], b: seq[Type], genericArgs: seq[string], map: var Table[string, Type]): bool

proc allZip*(a: seq[string], b: seq[string]): bool

proc isGeneric*(typ: Type, genericArgs: seq[string]): bool

proc mapGeneric*(typ: Type, map: Table[string, Type]): Type

proc unify(a: Type, b: Type, genericArgs: seq[string], map: var Table[string, Type]): bool =
  if cast[pointer](a) == nil:
    return cast[pointer](b) == nil
  elif cast[pointer](b) == nil:
    return cast[pointer](a) == nil
  elif a.kind == Default or b.kind == Default:
    return true
  elif b.kind != Simple and a.label != b.label:
    return false
  else:
    case b.kind:
    of Simple:
      if isGeneric(b, genericArgs):
        if map.hasKey(b.label):
          return a == map[b.label]
        else:
          map[b.label] = a
          return true
      else:
        return a.kind == Simple and a.label == b.label
    of Complex:
      if a.kind != Complex: return false
      return unifyAll(a.args, b.args, genericArgs, map)
    of Generic:
      return false
    of Overload:
      if a.kind != Overload: return false
      return unifyAll(a.overloads, b.overloads, genericArgs, map)
    of Default:
      return true
    of Record:
      if a.kind != Record: return false
      return true


proc allZip*(a: seq[string], b: seq[string]): bool =
  if len(a) != len(b):
    return false
  for j in low(a)..high(a):
    if a[j] != b[j]:
      return false
  return true

proc unifyAll*(a: seq[Type], b: seq[Type], genericArgs: seq[string], map: var Table[string, Type]): bool =
  if len(a) != len(b):
    return false
  for j in low(a)..high(a):
    if not unify(a[j], b[j], genericArgs, map):
      return false
  return true

proc `==`*(typ: Type, b: Type): bool =
  var map = initTable[string, Type]()
  if cast[pointer](typ) == nil:
    return cast[pointer](b) == nil
  elif cast[pointer](b) == nil:
    return cast[pointer](typ) == nil
  elif typ.kind == Default or b.kind == Default:
    return true
  elif typ.kind != b.kind:
    return false
  elif typ.label != b.label:
    return false
  else:
    case typ.kind:
    of Simple:
      return true
    of Complex:
      return unifyAll(typ.args, b.args, @[], map)
    of Generic:
      return allZip(typ.genericArgs, b.genericArgs) and typ.complex == b.complex
    of Overload:
      return unifyAll(typ.overloads, b.overloads, @[], map)
    of Default:
      return true
    of Record:
      return true

proc simple*(typ: Type): string =
  if typ == nil:
    return "nil"
  case typ.kind:
  of Simple:
    result = typ.label
  of Complex:
    result = "$1[$2]" % [typ.label, typ.args.mapIt(simple(it)).join(" ")]
  of Generic:
    result = "$1[$2][$3]" % [typ.label, typ.genericArgs.join(" "), typ.complex.args.mapIt(simple(it)).join(" ")]
  of Default:
    result = "Default"
  of Record:
    result = typ.label
  else:
    result = ""

proc isGeneric*(typ: Type, genericArgs: seq[string]): bool =
  case typ.kind:
  of Simple:
    return typ.label in genericArgs
  of Complex:
    return typ.args.anyIt(isGeneric(it, genericArgs))
  of Generic:
    return true
  of Overload:
    return typ.overloads.anyIt(isGeneric(it, genericArgs))
  of Default:
    return false
  of Record:
    return false

proc mapGeneric*(typ: Type, map: Table[string, Type]): Type =
  case typ.kind:
  of Simple:
    if map.hasKey(typ.label):
      return map[typ.label]
    else:
      return typ
  of Complex:
    return Type(kind: Complex, label: typ.label, args: typ.args.mapIt(mapGeneric(it, map)))
  of Generic:
    return Type(kind: Generic, label: typ.label, genericArgs: typ.genericArgs, complex: mapGeneric(typ.complex, map))
  of Overload:
    return Type(kind: Overload, label: typ.label, overloads: typ.overloads.mapIt(mapGeneric(it, map)))
  of Default:
    return typ
  of Record:
    var record = initTable[string, Type]()
    for label, field in typ.fields:
      record[label] = mapGeneric(field, map)
    return Type(kind: Record, label: typ.label, fields: record)

