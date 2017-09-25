import osproc, strutils, sequtils, tables, ospaths, os
import env, backend, breeze, macros
import unittest

const BACKENDS = @[BackendAsm, BackendC, BackendEvaluator]


template checkRoswell(s: untyped, path: untyped): untyped =
  let output = execProcess("./roswell $1 c --eval --test" % `path`)[0.. < ^1]
  var source = readFile(`path`)
  var lines = source.splitLines()
  var exp = ""
  for z in countdown(high(lines) - 1, low(lines)):
    if len(lines[z]) < 2 or lines[z][0..<2] != "# ":
      exp = lines[z + 1..len(lines) - 2].mapIt(it.split("# ", 1)[1]).join("\n")
      break
  # if output != exp:
  #   echo output, "\n", exp
  check(output == exp)

macro testsFor(path: static[string]): untyped =
  var tests = nnkStmtList.newTree()
  for filename in walkDir(path):
    var (dir, l, ext) = splitFile(filename[1])
    var labelNode = newIdentNode(!l)
    var label = newLit(l)
    var f = newLit(filename[1])
    var g = getAst(checkRoswell(l, filename[1]))
    var test = buildMacro:
      command:
        ident("test")
        label
        stmtList:
          g
    tests.add(test)
  result = tests
  echo repr(result)

suite "behavior":
  testsFor "tests/cases"

#   program "float", @["3.14"]
#   program "bool", @["false"]
#   program "array_int", @["_[2 4]"]
#   program "array_string", @["_['love' 'people']"]
#   program "type_error_assignment", @[
#     "x:",
#     "  expected Int",
#     "  got      Bool"]
#   program "type_error_array", @[
#     "element:",
#     "  expected Int",
#     "  got      Bool"]
#   program "type_error_list", @[
#     "element:",
#     "  expected Int",
#     "  got      Bool"]
#   program "type_error_if", @[
#     "if:",
#     "  expected Bool",
#     "  got      Int"]
