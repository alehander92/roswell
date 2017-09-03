import ast, errors, types
import tables, strutils, sequtils, terminal

const test = false

proc a(source: string): string

proc parseFunction(buffer: string, depth: int = 0): (bool, string, Node)
proc parseSignature(buffer: string, depth: int = 0): (bool, string, Node)
proc parseHead(buffer: string, depth: int = 0): (bool, string, Node)
proc parseArgs(buffer: string, depth: int = 0): (bool, string, Node)
proc parseGroup(buffer: string, depth: int = 0): (bool, string, Node)
proc parseReturn(buffer: string, depth: int = 0): (bool, string, Node)
proc parseIf(buffer: string, depth: int = 0): (bool, string, Node)
proc parseRaw(buffer: string, s: string, depth: int = 0): (bool, string, Node)
proc parseStatement(buffer: string, depth: int = 0): (bool, string, Node)
proc parseExpression(buffer: string, depth: int = 0): (bool, string, Node)
proc parseBasic(buffer: string, depth: int = 0): (bool, string, Node)
proc parseHelper(buffer: string, depth: int = 0): (bool, string, Node)
proc parseWs(buffer: string, depth: int = 0): (bool, string, Node)
proc parseNl(buffer: string, depth: int = 0): (bool, string, Node)
proc parseType(buffer: string, depth: int = 0): (bool, string, Node)
proc parseLabel(buffer: string, depth: int = 0): (bool, string, Node)
proc parseIndent(buffer: string, depth: int = 0): (bool, string, Node)
proc parseDedent(buffer: string, depth: int = 0): (bool, string, Node)
proc parseCallArgs(buffer: string, depth: int = 0): (bool, string, Node)
proc fillNode(node: Node, into: Node): Node
proc skip(buffer: string): string

template decl: untyped {.dirty.} =
  var success: bool = true
  var left:    string
  var node:    Node
  var z:       Node
  var zs:      bool

template raw(a: untyped): untyped =
  (success, left, z) = parseRaw(left, `a`, depth + 1)

template testLog(a: untyped): untyped =
  when test: echo repeat("  ", depth) & "parse" & `a` & ":" & buffer

proc parse*(source: string, name: string): Node =
  result = Node(kind: AProgram, name: name, functions: @[])
  decl
  left = a(source)
  var success2 = false
  while success:
    (success, left, node) = parseFunction(left, 0)
    if success:
      result.functions.add(node)
      (success2, left, z) = parseNl(left, 0)
  styledWriteLine(stdout, fgGreen, "PARSE\n", $result, resetStyle)
  if len(left) > 0:
    raise newException(RoswellError, "left: '$1'" % left)

var TAB = 2
var INDENT_TYPE = "@@@INDENT@@@"
var DEDENT_TYPE = "@@@DEDENT@@@"

proc a(source: string): string =
  var indent = 0
  var lines = source.splitLines()
  var res: seq[string] = @[]
  for j, line in lines:
    var offset = 0
    if len(line) > 0:
      for k in line:
        if k == ' ':
          inc offset
        else:
          break
    when test: echo indent, offset div TAB
    if (offset div TAB) > indent + 1:
      raise newException(RoswellError, "invalid indent")
    elif (offset div TAB) == indent + 1:
      res.add(INDENT_TYPE)
      res.add(line[offset..^1])
    elif (offset div TAB) == indent:
      res.add(line[offset..^1])
    else:
      for k in 0..<(indent - offset div TAB):
        res.add(DEDENT_TYPE)
      res.add(line[offset..^1])
    indent = offset div TAB
  return "$1\n" % res.join("\n")


proc parseFunction(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Function")
  var f = Node(kind: AFunction, params: @[])
  decl
  (success, left, node) = parseSignature(buffer, depth + 1)
  if success and node.kind == AFunction:
    f.types = node.types
    (success, left, node) = parseHead(left, depth + 1)
    if success and node.kind == AFunction:
      f.label = node.label
      f.params = node.params
      (success, left, node) = parseGroup(left, depth + 1)
      if success and node.kind == AGroup:
        f.code = node
        return (true, left, f)
  return (false, buffer, nil)

proc parseSignature(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Signature")
  var f = Node(kind: AFunction, params: @[])
  decl
  left = buffer
  if len(buffer) < 3:
    return (false, buffer, nil)
  elif buffer[0..2] == "def":
    f.types = Type(kind: Complex, label: Function, args: @[Type(kind: Simple, label: "Void")])
    return (true, buffer, f)
  else:
    f.types = Type(kind: Complex, label: Function, args: @[])
    while true:
      (success, left, node) = parseType(left, depth + 1)
      if success and node.kind == AType:
        f.types.args.add(node.typ)
        left = skip(left)
        if len(left) >= 2 and left[0..1] == "->":
          left = left[2..^1]
        left = skip(left)
      elif not success:
        (success, left, node) = parseNl(left, depth + 1)
        if success:
          return (true, left, f)
        else:
          return (false, buffer, nil)

proc parseHead(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Head")
  var f = Node(kind: AFunction, params: @[])
  decl
  (success, left, z) = parseRaw(buffer, "def", depth + 1)
  if success:
    left = skip(left)
    (success, left, node) = parseLabel(left, depth + 1)
    if success and node.kind == ALabel:
      f.label = node.s
      (success, left, node) = parseArgs(left, depth + 1)
      if success and node.kind == AFunction:
        f.params = node.params
        (success, left, z) = parseRaw(left, ":", depth + 1)
        if success:
          return (true, left, f)
  return (false, buffer, nil)

proc parseArgs(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Args")
  var f = Node(kind: AFunction, params: @[])
  decl
  left = buffer
  left = skip(left)
  if len(left) == 0:
    return (false, buffer, nil)
  elif left[0] == ':':
    return (true, left, f)
  else:
    raw("(")
    if success:
      while true:
        (success, left, node) = parseLabel(left, depth + 1)
        if success and node.kind == ALabel:
          f.params.add(node.s)
          left = skip(left)
        elif not success:
          raw(")")
          if success:
            return (true, left, f)
          else:
            return (false, buffer, nil)

proc parseGroup(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Group")
  var f = Node(kind: AGroup, nodes: @[])
  decl
  left = buffer
  (success, left, z) = parseIndent(left, depth + 1)
  if success:
    while true:
      (success, left, node) = parseStatement(left, depth + 1)
      if not success:
        (success, left, node) = parseExpression(left, depth + 1)
      if success:
        f.nodes.add(node)
        (success, left, z) = parseNl(left, depth + 1)
      if not success:
        (success, left, z) = parseDedent(left, depth + 1)
        if success:
          return (true, left, f)
        else:
          return (false, buffer, nil)

proc parseReturn(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Return")
  var f = Node(kind: AReturn)
  decl
  left = buffer
  raw("return")
  if success:
    left = skip(left)
    (success, left, node) = parseExpression(left, depth + 1)
    if success:
      f.ret = node
      return (true, left, f)
  return (false, buffer, nil)

proc parseIf(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("If")
  var f = Node(kind: AIf)
  decl
  left = buffer
  raw("if")
  if success:
    left = skip(left)
    (success, left, node) = parseExpression(left, depth + 1)
    if success:
      f.condition = node
      raw(":")
      if success:
        (success, left, node) = parseGroup(left, depth + 1)
        if success:
          f.success = node
          raw("else")
          if success:
            left = skip(left)
            raw(":")
            if success:
              (success, left, node) = parseGroup(left, depth + 1)
              if success:
                f.fail = node
                return (true, left, f)
          else:
            return (true, left, f)
  return (false, buffer, nil)

proc parseDefinition(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Definition")
  var f = Node(kind: ADefinition)
  decl
  left = buffer
  raw("var")
  if success:
    left = skip(left)
    (success, left, node) = parseLabel(left, depth + 1)
    if success:
      f.id = node.s
      left = skip(left)
      raw("=")
      if success:
        left = skip(left)
        (success, left, node) = parseExpression(left, depth + 1)
        if success:
          f.definition = Node(kind: AAssignment, target: f.id, res: node)
          return (true, left, f)
      else:
        raw("is")
        if success:
          left = skip(left)
          (success, left, node) = parseType(left, depth + 1)
          if success:
            f.definition = node
            return (true, left, f)
  return (false, buffer, nil)


var STATEMENT_FUNCTIONS = [parseReturn, parseIf, parseDefinition]

proc parseStatement(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Statement")
  decl
  left = buffer
  for function in STATEMENT_FUNCTIONS:
    (success, left, node) = function(left, depth + 1)
    if success:
      return (true, left, node)
  return (false, buffer, nil)

proc parseExpression(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Expression")
  decl
  var basicNode: Node
  var helperNode: Node
  var expressionNode: Node
  
  (success, left, basicNode) = parseBasic(buffer, depth + 1)
  if success:
    left = skip(left)
    (success, left, helperNode) = parseHelper(left, depth + 1)
    if success:
      if helperNode != nil:
        helperNode = fillNode(basicNode, helperNode)
        return (true, left, helperNode)
      else:
        return (true, left, basicNode)

  (success, left, node) = parseRaw(left, "(", depth + 1)
  if success:
    left = skip(left)
    (success, left, expressionNode) = parseExpression(left, depth + 1)
    if success:
      left = skip(left)
      (success, left, node) = parseRaw(left, ")", depth + 1)
      if success:
        return (true, left, expressionNode)

  return (false, buffer, nil)

proc parseMember(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Member")
  var f = Node(kind: AMember)
  decl
  if len(buffer) == 0 or buffer[0] != '.':
    return (false, buffer, nil)
  (success, left, node) = parseLabel(buffer[1..^1], depth + 1)
  if success and node.kind == ALabel:
    f.member = node.s
    return (true, left, f)
  return (false, buffer, nil)

proc parseCall(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Call")
  var f = Node(kind: ACall, args: @[])
  decl

  if len(buffer) == 0 or buffer[0] != '(':
    return (false, buffer, nil)
  (success, left, node) = parseCallArgs(buffer[1..^1], depth + 1)
  if success and node.kind == AGroup:
    f.args = node.nodes
    return (true, left, f)
  return (false, buffer, nil)

proc parseIndex(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Index")
  var f = Node(kind: AIndex)
  decl

  if len(buffer) == 0 or buffer[0] != '[':
    return (false, buffer, nil)

  (success, left, node) = parseExpression(buffer[1..^1], depth + 1)
  if success:
    if len(left) > 0 and left[0] == ']':
      f.index = node
      return (true, left[1..^1], f)
  return (false, buffer, nil)

const HELPER_FUNCTIONS = @[parseMember, parseCall, parseIndex]

proc parseHelper(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Helper")
  decl
  var leftZ: string
  var bufferA: string
  var helperNode: Node

  bufferA = skip(buffer)
  for function in HELPER_FUNCTIONS:
    (success, left, node) = function(bufferA, depth + 1)
    if success:
      (success, leftZ, helperNode) = parseHelper(left, depth + 1)
      if success and helperNode != nil:
        helperNode = fillNode(node, helperNode)
        return (true, leftZ, helperNode)
      return (true, left, node)
  return (true, buffer, nil)

var OPERATORS = {"and": OpAnd, "or": OpOr, "==": OpEq, "%": OpMod, "+": OpAdd, "-": OpSub, "*": OpMul, "/": OpDiv}.toTable

proc parseOperator(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Operator")
  decl
  left = buffer
  for s, operator in OPERATORS:
    (success, left, node) = parseRaw(left, $s, depth + 1)
    if success:
      return (true, left, Node(kind: AOperator, op: operator))
  return (false, buffer, nil)

proc literal(isFloat: bool, buffer: string): Node =
  if isFloat:
    result = Node(kind: AFloat, f: parseFloat($(buffer)))
  else:
    result = Node(kind: AInt, value: parseInt($(buffer)))

proc parseNumber(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Number")
  var isFloat = false
  for a, b in buffer:
    if b == '.':
      if isFloat:
        return (false, buffer, nil)
      else:
        isFloat = true
    elif not b.isDigit():
      if a == 0:
        return (false, buffer, nil)
      else:
        return (true, buffer[a..^1], literal(isFloat, buffer[0..<a]))
  if len(buffer) == 0:
    return (false, buffer, nil)
  else:
    return (true, "", literal(isFloat, buffer))

proc parseBool(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Bool")
  var (success, left, node) = parseRaw(buffer, "true", depth + 1)
  if success:
    return (true, left, Node(kind: ABool, b: true))
  (success, left, node) = parseRaw(buffer, "false", depth + 1)
  if success:
    return (true, left, Node(kind: ABool, b: false))
  return (false, buffer, nil)

proc parseArray(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Array")
  var f = Node(kind: AArray, elements: @[])
  decl
  if len(buffer) < 2 or buffer[0] != '_' or buffer[1] != '[':
    return (false, buffer, nil)
  left = buffer[2..^1]
  while true:
    (success, left, node) = parseExpression(left, depth + 1)
    if success:
      f.elements.add(node)
      left = skip(left)
    else:
      if len(left) > 0 and left[0] == ']':
        return (true, left[1..^1], f)
      else:
        return (false, buffer, nil)

proc parseString(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("String")
  if len(buffer) == 0 or buffer[0] != '\'':
    return (false, buffer, nil)
  var left = buffer[1..^1]
  for a, b in left:
    if b == '\'':
      return (true, buffer[2 + a..^1], Node(kind: AString, s: $(buffer[1..a])))
  return (false, buffer, nil)


var BASIC_FUNCTIONS = @[parseLabel, parseNumber, parseBool, parseString, parseArray, parseOperator] #, parseLabel, parseOperator, parseString]

proc parseBasic(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Basic")
  decl

  for function in BASIC_FUNCTIONS:
    (success, left, node) = function(buffer, depth + 1)
    if success:
      return (true, left, node)
  return (false, buffer, nil)

proc parseRaw(buffer: string, s: string, depth: int = 0): (bool, string, Node) =
  testLog("Raw")
  for i in low(s)..high(s):
    if i + 1 > len(buffer) or buffer[i] != s[i]:
      return (false, buffer, nil)
  return (true, buffer[len(s)..^1], Node(kind: AString, s: s))

proc parseWs(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Ws")
  for a, b in buffer:
    if b != ' ':
      if a > 0:
        return (true, buffer[a..^1], nil)
      else:
        break
    elif a == len(buffer) - 1:
      return (true, "", nil)
  return (false, buffer, nil)

proc parseNl(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Nl")
  for a, b in buffer:
    if b notin NewLines:
      if a > 0:
        return (true, buffer[a..^1], nil)
      else:
        break
    elif a == len(buffer) - 1:
      return (true, "", nil)
  return (false, buffer, nil)

proc parseType(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Type")
  var f = Node(kind: AType)
  decl
  left = skip(buffer)
  if len(left) == 0:
    return (false, buffer, nil)
  if left[0] == '[':
    (success, left, node) = parseType(left[1..^1], depth + 1)
    if success and node.kind == AType and len(left) > 0 and left[0] == ']':
      f.typ = Type(kind: Complex, label: "List", args: @[node.typ])
      return (true, left[1..^1], f)
  elif len(left) > 1 and left[0] == '_' and left[1] == '[':
    (success, left, node) = parseType(left[2..^1], depth + 1)
    if success and node.kind == AType:
      raw(",")
      left = skip(left)
      var intNode: Node
      (success, left, intNode) = parseNumber(left, depth + 1)
      if success and intNode.kind == AInt and len(left) > 0 and left[0] == ']':
        f.typ = Type(kind: Complex, label: "Array", args: @[node.typ, Type(kind: Simple, label: $intNode.value)])
        return (true, left[1..^1], f)
  else:
    (success, left, node) = parseLabel(left, depth + 1)
    if success and node.kind == ALabel:
      f.typ = Type(kind: Simple, label: node.s)
      return (true, left, f)
  return (false, buffer, nil)

proc parseLabel(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Label")
  for a, b in buffer:
    if not b.isAlphaAscii():
      if a == 0:
        return (false, buffer, nil)
      else:
        return (true, buffer[a..^1], Node(kind: ALabel, s: $(buffer[0..<a])))
  if len(buffer) == 0:
    return (false, buffer, nil)
  else:
    return (true, "", Node(kind: ALabel, s: $buffer))

proc parseIndent(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Indent")
  decl
  (success, left, z) = parseNl(buffer, depth + 1)
  if success:
    (success, left, z) = parseRaw(left, INDENT_TYPE, depth + 1)
    if success:
      (success, left, z) = parseNl(left, depth + 1)
      if success:
        return (true, left, nil)
  return (false, buffer, nil)

proc parseDedent(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Dedent")
  decl
  (success, left, z) = parseRaw(buffer, DEDENT_TYPE, depth + 1)
  if success:
    (success, left, z) = parseNl(left, depth + 1)
    if success:
      return (true, left, nil)
  return (false, buffer, nil)

proc parseCallArgs(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("CallArgs")
  var f = Node(kind: AGroup, nodes: @[])
  decl
  
  left = skip(buffer)
  while true:
    (success, left, node) = parseExpression(left, depth + 1)
    if success:
      f.nodes.add(node)
      left = skip(left)
      if len(left) > 0 and left[0] == ')':
        return (true, left[1..^1], f)
    else:
      if len(left) > 0 and left[0] == ')':
        return (true, left[1..^1], f)
      else:
        return (false, buffer, nil)

proc fillNode(node: Node, into: Node): Node =
  if into == nil:
    return node
  case into.kind:
  of ACall:
    if into.function == nil:
      into.function = node
    else:
      into.function = fillNode(node, into.function)
  of AMember:
    if into.receiver == nil:
      into.receiver = node
    else:
      into.receiver = fillNode(node, into.receiver)
  of AIndex:
    if into.indexable == nil:
      into.indexable = node
    else:
      into.indexable = fillNode(node, into.receiver)
  else: discard
  return into

proc skip(buffer: string): string =
  for a, b in buffer:
    if b != ' ':
      return buffer[a..^1]
    elif a == len(buffer) - 1:
      return ""
  return ""
