import ast, errors, types
import tables, strutils, sequtils, terminal

const test = true

proc a(source: string): string

proc parseFunction(buffer: string, depth: int = 0): (bool, string, Node)
proc parseSignature(buffer: string, depth: int = 0): (bool, string, Node)
proc parseHead(buffer: string, depth: int = 0): (bool, string, Node)
proc parseArgs(buffer: string, depth: int = 0): (bool, string, Node)
proc parseGroup(buffer: string, depth: int = 0): (bool, string, Node)
proc parseReturn(buffer: string, depth: int = 0): (bool, string, Node)
proc parseIf(buffer: string, depth: int = 0): (bool, string, Node)
proc parseForEach(buffer: string, depth: int = 0): (bool, string, Node)
proc parseRaw(buffer: string, s: string, depth: int = 0): (bool, string, Node)
proc parseStatement(buffer: string, depth: int = 0): (bool, string, Node)
proc parseTypeDefinition(buffer: string, depth: int = 0): (bool, string, Node)
proc parseExpression(buffer: string, depth: int = 0): (bool, string, Node)
proc parseNl(buffer: string, depth: int = 0): (bool, string, Node)
proc parseBasic(buffer: string, depth: int = 0): (bool, string, Node)
proc parseHelper(buffer: string, depth: int = 0): (bool, string, Node)
proc parseWs(buffer: string, depth: int = 0): (bool, string, Node)
proc parseIField(buffer: string, depth: int = 0): (bool, string, Node)
proc parseRecord(buffer: string, depth: int = 0): (bool, string, Node)
proc parseEnum(buffer: string, depth: int = 0): (bool, string, Node)    
proc parseType(buffer: string, depth: int = 0, application: bool = false): (bool, string, Node)
proc parseLabel(buffer: string, depth: int = 0): (bool, string, Node)
proc parseTitle(buffer: string, depth: int = 0): (bool, string, Node)
proc parseIndent(buffer: string, depth: int = 0): (bool, string, Node)
proc parseDedent(buffer: string, depth: int = 0): (bool, string, Node)
proc parseCallArgs(buffer: string, depth: int = 0): (bool, string, Node)
proc fillNode(node: Node, into: Node): Node
proc skip(buffer: string): string


var contexts: Table[int, Location] = initTable[int, Location]()
var locations: Table[int, seq[Location]] = initTable[int, seq[Location]]()
var fileId: int = 0

var TAB = 2
var INDENT_TYPE = "{{{INDENT}}}"
var DEDENT_TYPE = "{{{DEDENT}}}"

proc loca(buffer: string): Location =
  # returns char location
  if len(buffer) == 0:
    result = locations[fileId][0]
  else:
    result = locations[fileId][^len(buffer)]

template decl: untyped {.dirty.} =
  var success: bool = true
  var left:    string
  var node:    Node
  var z:       Node
  var zs:      bool

template raw(a: untyped): untyped =
  (success, left, z) = parseRaw(left, `a`, depth + 1)

template testLog(a: untyped): untyped =
  when test: echo repeat("  ", depth) & "parse" & `a` & ":" & (if len(buffer) > 16: buffer[0..<16] else: buffer)

template loc: untyped =
  loca(buffer)
  
template locLeft: untyped =
  loca(left)

proc preprocess(source: string, id: int): seq[Location] =
  result = @[]
  var line = 0
  var column = 1
  var inString = false
  var offset = 0
  var z = 0
  while z < len(source):
    var c = source[z]
    result.add(Location(line: line, column: column, fileId: id))
    if c in NewLines:
      if not inString:
        column = 1
        inc line
        inc z
        # echo result.filterIt(it.line == line - 1)
        continue
      inc column
      inc z
    elif c == '\'' and (z == 0 or source[z - 1] != '\\'):
      inString = not inString
      inc column
      inc z
    elif z < len(source) - len(INDENT_TYPE) and source[z..(z + len(INDENT_TYPE) - 1)] == INDENT_TYPE:
      inc offset
      for symbol in INDENT_TYPE[1..^1]:
        inc z
        result.add(Location(line: line, column: column, fileId: id))
      column += TAB * offset
    elif z < len(source) - len(DEDENT_TYPE) and source[z..(z + len(DEDENT_TYPE) - 1)] == DEDENT_TYPE:
      dec offset
      for symbol in DEDENT_TYPE[1..^1]:
        inc z
        result.add(Location(line: line, column: column, fileId: id))
      column += TAB * offset
    else:
      inc column
      inc z

proc parse*(source: string, name: string, id: int = 0): Node =
  result = Node(kind: AProgram, name: name, functions: @[], definitions: @[])
  decl
  left = a(source)
  contexts[id] = Location(line: 1, column: 1, fileId: id)
  result.location = contexts[id]
  names[id] = "$1.roswell" % name
  locations[id] = preprocess(left, id)
  fileId = id
  var success2 = false
  while success:
    (success, left, node) = parseTypeDefinition(left, 0)
    if success:
      result.definitions.add(node)
      (success2, left, z) = parseNl(left, 0)
  success = true
  success2 = false
  while success:
    (success, left, node) = parseFunction(left, 0)
    if success:
      result.functions.add(node)
      (success2, left, z) = parseNl(left, 0)
  styledWriteLine(stdout, fgGreen, "PARSE\n", $result, resetStyle)
  if len(left) > 0:
    raise newException(RoswellError, "left: '$1'" % left)

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
    if len(res) > 0:
      var s = false
      var m = ""
      for z, c in res[^1]:
        if c == '\'' and (z == 0 or res[^1][z - 1] != '\\'):
          s = not s
        elif c == '#' and not s:
          break
        m.add(c)
      res[^1] = m
    indent = offset div TAB
  return "$1\n" % res.join("\n")


proc parseFunction(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Function")
  var f = Node(kind: AFunction, params: @[], location: loc)
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
  var f = Node(kind: AFunction, params: @[], location: loc)
  decl
  left = buffer
  if len(buffer) < 3:
    return (false, buffer, nil)
  elif buffer[0..2] == "def":
    f.types = Type(kind: Complex, label: Function, args: @[Type(kind: Simple, label: "Void")])
    return (true, buffer, f)
  else:
    f.types = Type(kind: Complex, label: Function, args: @[])
    (success, left, node) = parseType(left, depth + 1, application=true)
    if success and node.kind == AType:
      f.types = node.typ
      (success, left, node) = parseNl(left, depth + 1)
      if success:
        return (true, left, f)

proc parseHead(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Head")
  var f = Node(kind: AFunction, params: @[], location: loc)
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
  var f = Node(kind: AFunction, params: @[], location: loc)
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
  var f = Node(kind: AGroup, nodes: @[], location: loc)
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
        success = true
      if not success:
        (success, left, z) = parseDedent(left, depth + 1)
        if success:
          return (true, left, f)
        else:
          return (false, buffer, nil)

proc parseReturn(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Return")
  var f = Node(kind: AReturn, location: loc)
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
  var f = Node(kind: AIf, location: loc)
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

proc parseForEach(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("ForEach")
  var f = Node(kind: AForEach, location: loc)
  decl
  left = buffer
  raw("for")
  var firstLabel: Node
  var secondLabel: Node
  if success:
    left = skip(left)
    (success, left, node) = parseLabel(left, depth + 1)
    if success and node.kind == ALabel:
      firstLabel = node
      left = skip(left)
      (success, left, node) = parseLabel(left, depth + 1)
      if success and node.kind == ALabel:
        secondLabel = node
        left = skip(left)
      if secondLabel == nil:
        f.forEachIndex = ""
        f.iter = firstLabel.s
      else:
        f.forEachIndex = firstLabel.s
        f.iter = secondLabel.s
      raw("in")
      if success:
        left = skip(left)
        (success, left, node) = parseExpression(left, depth + 1)
        if success:
          f.forEachSeq = node
          raw(":")
          if success:
            (success, left, node) = parseGroup(left, depth + 1)
            if success:
              f.forEachBlock = node
              return (true, left, f)
  return (false, buffer, nil)

proc parseAssignment(buffer: string, depth: int = 0): (bool, string, Node) =
  var f = Node(kind: AAssignment, location: loc)
  decl

  (success, left, node) = parseLabel(buffer, depth + 1)
  if success:
    f.target = node.s
    if len(left) > 0 and left[0] == '[':
      f = Node(kind: AIndexAssignment, location: loc)
      f.aIndex = Node(kind: AIndex, indexable: node, location: loc)
      left = left[1..^1]
      left = skip(left)
      (success, left, node) = parseExpression(left, depth + 1)
      if success:
        f.aIndex.index = node
        left = skip(left)
        raw("]")
        if success:
          left = skip(left)

          raw("=")
          if success:
            left = skip(left)

            (success, left, node) = parseExpression(left, depth + 1)
            if success:
              f.aValue = node
              return (true, left, f)
      return (false, buffer, nil)
    elif len(left) > 0 and left[0] == '@':
      f.isDeref = true
      left = left[1..^1]
    left = skip(left)

    raw("=")
    if success:
      left = skip(left)
      (success, left, node) = parseExpression(left, depth + 1)
      if success:
        f.res = node
        return (true, left, f)
  return (false, buffer, nil)

proc parseDefinition(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Definition")
  var f = Node(kind: ADefinition, location: loc)
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
          f.definition = Node(kind: AAssignment, target: f.id, res: node, location: locLeft)
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

var STATEMENT_FUNCTIONS = [parseAssignment, parseReturn, parseIf, parseForEach, parseDefinition]

proc parseStatement(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Statement")
  decl
  left = buffer
  for function in STATEMENT_FUNCTIONS:
    (success, left, node) = function(left, depth + 1)
    if success:
      return (true, left, node)
  return (false, buffer, nil)

var DEFINITION_FUNCTIONS = [parseRecord, parseEnum]

proc parseTypeDefinition(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("TypeDefinition")
  decl
  left = buffer
  for function in DEFINITION_FUNCTIONS:
    (success, left, node) = function(left, depth + 1)
    if success:
      return (true, left, node)
  return (false, buffer, nil)

proc parseField(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Field")
  var f = Node(kind: AField, location: loc)
  decl
  (success, left, node) = parseLabel(buffer, depth + 1)
  if success and node.kind == ALabel:
    f.fieldLabel = node.s
    left = skip(left)
    raw("is")
    if success:
      left = skip(left)
      (success, left, node) = parseType(left, depth + 1)
      if success and node.kind == AType:
        f.fieldType = node.typ
        return (true, left, f)
  return (false, buffer, nil)

proc parseRecord(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Record")
  var f = Node(kind: ARecord, fields: @[], location: loc)
  decl
  left = buffer
  raw("record")
  if success:
    left = skip(left)
    (success, left, node) = parseTitle(left, depth + 1)
    if success and node.kind == ALabel:
      f.rLabel = node.s
      raw(":")
      if success:
        (success, left, node) = parseIndent(left, depth + 1)
        if success:
          var success2 = false
          while success:
            (success, left, node) = parseField(left, depth + 1)
            if success:
              f.fields.add(node)
              (success2, left, z) = parseNl(left, depth + 1)
          (success, left, node) = parseDedent(left, depth + 1)
          if success:
            return (true, left, f)
  return (false, buffer, nil)

proc parseEnum(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Enum")
  var f = Node(kind: AEnum, variants: @[], location: loc)
  decl
  left = buffer
  raw("enum")
  if success:
    left = skip(left)
    (success, left, node) = parseTitle(left, depth + 1)
    if success and node.kind == ALabel:
      f.eLabel = node.s
      raw(":")
      if success:
        left = skip(left)
        var success2 = false
        while success:
          raw("~")
          if success:
            (success, left, node) = parseLabel(left, depth + 1)
            if success and node.kind == ALabel:
              f.variants.add("~$1" % node.s)
        if len(f.variants) > 0:
          return (true, left, f)
  return (false, buffer, nil)


proc parseDeref(buffer: string, depth: int): (bool, string, Node) =
  testLog("Deref")
  var f = Node(kind: ADeref, location: loc)
  decl


  
  if len(buffer) > 0 and buffer[0] == '@':
    return (true, buffer[1..^1], f)
  return (false, buffer, nil)

proc parseExpression(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Expression")
  decl
  var basicNode: Node
  var helperNode: Node
  var expressionNode: Node
  var resultNode: Node

  (success, left, basicNode) = parseBasic(buffer, depth + 1)
  if success:
    left = skip(left)
    (success, left, helperNode) = parseHelper(left, depth + 1)
    if success:
      if helperNode != nil:
        helperNode = fillNode(basicNode, helperNode)
        resultNode = helperNode
      else:
        resultNode = basicNode
      return (true, left, resultNode)

  (success, left, node) = parseRaw(buffer, "(", depth + 1)
  if success:
    left = skip(left)
    (success, left, expressionNode) = parseExpression(left, depth + 1)
    if success:
      left = skip(left)
      (success, left, node) = parseRaw(left, ")", depth + 1)
      if success:
        return (true, left, expressionNode)

  (success, left, node) = parseTitle(buffer, depth + 1)
  if success and node.kind == ALabel:
    var f = Node(kind: AInstance, iFields: @[], location: loc)
    f.iLabel = node.s
    left = skip(left)
    raw("(")
    if success:
    
      while success:
        (success, left, node) = parseIField(left, depth + 1)
        if success:
          f.iFields.add(node)
          left = skip(left)
      raw(")")
      if success:
        return (true, left, f)
  return (false, buffer, nil)

proc parseIField(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("IField")
  var f = Node(kind: AIField, location: loc)
  decl
  (success, left, node) = parseLabel(buffer, depth + 1)
  if success and node.kind == ALabel:
    f.iFieldLabel = node.s
    left = skip(left)
    raw("=")
    if success:
      left = skip(left)
      (success, left, node) = parseExpression(left, depth + 1)
      if success:
        f.iFieldValue = node
        return (true, left, f)
  return (false, buffer, nil)


proc parseMember(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Member")
  var f = Node(kind: AMember, location: loc)
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
  var f = Node(kind: ACall, args: @[], location: loc)
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
  var f = Node(kind: AIndex, location: loc)
  decl

  if len(buffer) == 0 or buffer[0] != '[':
    return (false, buffer, nil)

  (success, left, node) = parseExpression(buffer[1..^1], depth + 1)
  if success:
    if len(left) > 0 and left[0] == ']':
      f.index = node
      return (true, left[1..^1], f)
  return (false, buffer, nil)

proc parsePointer(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Pointer")
  var f = Node(kind: APointer, location: loc)
  decl

  if len(buffer) == 0 or buffer[0] != '@':
    return (false, buffer, nil)

  (success, left, node) = parseExpression(buffer[1..^1], depth + 1)
  if success:
    f.targetObject = node
    return (true, left, f)
  return (false, buffer, nil)

const HELPER_FUNCTIONS = @[parseMember, parseCall, parseIndex, parseDeref]

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
      return (true, left, Node(kind: AOperator, op: operator, location: locLeft))
  return (false, buffer, nil)

proc literal(isFloat: bool, buffer: string, location: Location): Node =
  if isFloat:
    result = Node(kind: AFloat, f: parseFloat($(buffer)), location: location)
  else:
    result = Node(kind: AInt, value: parseInt($(buffer)), location: location)

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
        return (true, buffer[a..^1], literal(isFloat, buffer[0..<a], loc))
  if len(buffer) == 0:
    return (false, buffer, nil)
  else:
    return (true, "", literal(isFloat, buffer, loc))

proc parseBool(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Bool")
  var (success, left, node) = parseRaw(buffer, "true", depth + 1)
  if success:
    return (true, left, Node(kind: ABool, b: true, location: locLeft))
  (success, left, node) = parseRaw(buffer, "false", depth + 1)
  if success:
    return (true, left, Node(kind: ABool, b: false, location: locLeft))
  return (false, buffer, nil)

proc parseArray(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Array")
  var f = Node(kind: AArray, elements: @[], location: loc)
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
    if b == '\'' and (a == 0 or left[a - 1] != '\\'):
      return (true, buffer[2 + a..^1], Node(kind: AString, s: $(buffer[1..a]), location: loc))
  return (false, buffer, nil)


var BASIC_FUNCTIONS = @[parseLabel, parseNumber, parseBool, parseString, parseArray, parseOperator, parsePointer] #, parseLabel, parseOperator, parseString]

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
  return (true, buffer[len(s)..^1], Node(kind: AString, s: s, location: loc))

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
  var left = skip(buffer)
  for a, b in left:
    if b notin NewLines:
      if a > 0:
        return (true, left[a..^1], nil)
      else:
        break
    elif a == len(left) - 1:
      return (true, "", nil)
  return (false, buffer, nil)

proc parseType(buffer: string, depth: int = 0, application: bool = false): (bool, string, Node) =
  testLog("Type")
  var f = Node(kind: AType, location: loc)
  decl
  left = skip(buffer)
  if len(left) == 0:
    return (false, buffer, nil)

  if application:
    if left[0] == '<':
      f.typ = Type(kind: Generic, genericArgs: @[], instantiations: @[], label: Function)
      left = left[1..^1]
      while true:
        echo ":", left[0..<20]
        if len(left) > 0 and left[0] == '>':
          left = left[1..^1]
          left = skip(left)
          break
        (success, left, node) = parseTitle(left, depth + 1)
        if success and node.kind == ALabel:
          f.typ.genericArgs.add(node.s)
          left = skip(left)
        else:
          return (false, buffer, nil)
    else:
      f.typ = Type(kind: Complex, label: Function, args: @[])
    var typ = Type(kind: Complex, label: Function, args: @[])
    while true:
      (success, left, node) = parseType(left, depth + 1)
      if success and node.kind == AType:
        typ.args.add(node.typ)
        left = skip(left)
        if len(left) >= 2 and left[0..1] == "->":
          left = left[2..^1]
        left = skip(left)
      elif not success:
        if f.typ.kind == Generic:
          f.typ.complex = typ
        else:
          f.typ = typ
        return (true, left, f)
    return (false, buffer, nil)
  elif left[0] == '[':
    (success, left, node) = parseType(left[1..^1], depth + 1)
    if success and node.kind == AType and len(left) > 0 and left[0] == ']':
      f.typ = Type(kind: Complex, label: "List", args: @[node.typ])
      return (true, left[1..^1], f)
  elif len(left) > 1 and left[0] == '_' and left[1] == '[':
    (success, left, node) = parseType(left[2..^1], depth + 1)
    if success and node.kind == AType:
      left = skip(left)
      var intNode: Node
      (success, left, intNode) = parseNumber(left, depth + 1)
      if success and intNode.kind == AInt and len(left) > 0 and left[0] == ']':
        f.typ = Type(kind: Complex, label: "Array", args: @[node.typ, Type(kind: Simple, label: $intNode.value)])
        return (true, left[1..^1], f)
      else:
        (success, left, intNode) = parseTitle(left, depth + 1)
        if success and intNode.kind == ALabel and len(left) > 0 and left[0] == ']':
          f.typ = Type(kind: Complex, label: "Array", args: @[node.typ, Type(kind: Simple, label: intNode.s)])
          return (true, left[1..^1], f)          
  elif len(left) > 1 and left[0] == '(':
    (success, left, node) = parseType(left[1..^1], depth + 1, application=true)
    if success and node.kind == AType:
      raw(")")
      if success:
        f.typ = node.typ
        return (true, left, f)
  else:
    (success, left, node) = parseTitle(left, depth + 1)
    if success and node.kind == ALabel:
      f.typ = Type(kind: Simple, label: node.s)
      return (true, left, f)
  return (false, buffer, nil)

proc parseLabelRaw(buffer: string, depth: int = 0, capital: bool = false): (bool, string, Node) =
  testLog("LabelRaw")
  for a, b in buffer:
    if not b.isAlphaAscii():
      if a == 0:
        return (false, buffer, nil)
      else:
        if a == 1:
          if capital and not buffer[0].isUpperAscii():
            return (false, buffer, nil)
        if not capital and not buffer[0].isLowerAscii():
          return (false, buffer, nil)
        return (true, buffer[a..^1], Node(kind: ALabel, s: $(buffer[0..<a]), location: loc))
  if len(buffer) == 0:
    return (false, buffer, nil)
  else:
    return (true, "", Node(kind: ALabel, s: $buffer, location: loc))

proc parseLabel(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Label")
  result = parseLabelRaw(buffer, depth=depth)

proc parseTitle(buffer: string, depth: int = 0): (bool, string, Node) =
  testLog("Title")
  result = parseLabelRaw(buffer, depth=depth, capital=true)

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
  var f = Node(kind: AGroup, nodes: @[], location: loc)
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
    into.location = into.function.location
  of AMember:
    if into.receiver == nil:
      into.receiver = node
    else:
      into.receiver = fillNode(node, into.receiver)
    into.location = into.receiver.location
  of AIndex:
    if into.indexable == nil:
      into.indexable = node
    else:
      into.indexable = fillNode(node, into.receiver)
    into.location = into.indexable.location
  of ADeref:
    if into.derefedObject == nil:
      into.derefedObject = node
    else:
      into.derefedObject = fillNode(node, into.derefedObject)
    into.location = into.derefedObject.location
  else: discard
  return into

proc skip(buffer: string): string =
  for a, b in buffer:
    if b != ' ':
      return buffer[a..^1]
    elif a == len(buffer) - 1:
      return ""
  return ""
