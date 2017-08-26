import strutils, sequtils

type
  TypeKind* = enum Simple, Complex, Generic, Overload

  Type* = ref object
    label*: string
    case kind*: TypeKind
    of Simple: discard
    of Complex:
      args*: seq[Type]
    of Generic:
      genericArgs*: seq[string]
      complex*: Type
    of Overload:
      overloads*: seq[Type]

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
      "Overload{$1, $2}" % [typ.label, typ.overloads.mapIt($it).join("  ")]
  result = repeat("  ", depth) & value

proc `$`*(typ: Type): string =
  result = render(typ, 0)

proc functionType*(args: seq[Type]): Type =
  result = Type(kind: Complex, label: Function, args: args)

proc allZip*[T](a: seq[T], b: seq[T]): bool =
  if len(a) != len(b):
    return false
  for j in low(a)..high(a):
    if a[j] != b[j]:
      return false
  return true

proc `==`*(typ: Type, b: Type): bool =
  if cast[pointer](typ) == nil:
    return cast[pointer](b) == nil
  elif cast[pointer](b) == nil:
    return cast[pointer](typ) == nil
  elif typ.kind != b.kind:
    return false
  elif typ.label != b.label:
    return false
  else:
    case typ.kind:
    of Simple:
      return true
    of Complex:
      return allZip(typ.args, b.args)
    of Generic:
      return allZip(typ.genericArgs, b.genericArgs) and typ.complex == b.complex
    of Overload:
      return allZip(typ.overloads, b.overloads)

