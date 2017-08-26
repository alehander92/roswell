import errors
import tables, strutils, sequtils

type
  Env*[T] = ref object
    locations*:   Table[string, T]
    parent*:      Env[T]
    top*:         Env[T]

proc getOrDefault*[T](e: Env[T], name: string): T

proc `[]`*[T](e: Env[T], name: string): T =
  result = getOrDefault(e, name)
  if result == nil:
    raise newException(RoswellError, "undefined $1" % name)

proc `[]=`*[T](e: var Env[T], name: string, operand: T) =
  e.locations[name] = operand

proc getOrDefault*[T](e: Env[T], name: string): T =
  var last = e
  while last != nil:
    if last.locations.hasKey(name):
      return last.locations[name]
    last = last.parent
  result = nil

proc newEnv*[T](e: Env[T]): Env[T] =
  result = Env[T](locations: initTable[string, T](), parent: e)
  result.top = if e == nil: result else: e.top

