import ast, types, options, env
import strutils, sequtils, tables, terminal

proc translateGeneric(function: Node, ast: Node, map: Table[string, Type], label: string): seq[Node]

proc simplifyGeneric(node: var Node, ast: Node): Node

proc instantiate*(ast: Node, options: Options = Options(debug: false, test: false)): Node =
  assert ast.kind == AProgram
  var newFunctions: seq[Node] = @[]
  for node in ast.functions.mitems:
    assert node.kind == AFunction
    if node.types.kind == Generic:
      for element in node.types.instantiations:
        if not element.isGeneric:
          newFunctions = concat(newFunctions, translateGeneric(node, ast, element.map, element.label))
    else:
      newFunctions.add(simplifyGeneric(node, ast))
  ast.functions = newFunctions
  if not options.test:
    styledWriteLine(stdout, fgGreen, "INSTANTIATE\n", $ast, resetStyle)
  return ast

proc translateNode(node: var Node, map: Table[string, Type], ast: Node, nodes: var seq[Node]) =
  if node.kind == ACall:
    if node.function.kind == ALabel and node.function.tag.kind == Generic:
      var translated = false
      for f in ast.functions:
        assert f.kind == AFunction
        if node.function.tag == f.types:
          assert f.types.kind == Generic
          for item in f.types.instantiations:
            if node.function.s == item.label:
              var newNodes = translateGeneric(f, ast, mapToMap(item.map, map), item.label)
              for n in newNodes:
                nodes.add(n)
              translated = true
              break
          if translated:
            break
  for child in node.mitems:
    translateNode(child, map, ast, nodes)
  if node.kind == AType:
    node.typ = mapGeneric(node.typ, map, simple=true)

  if node.tag != nil:
    node.tag = mapGeneric(node.tag, map, simple=true)
  
proc translateNode(node: Node, map: Table[string, Type], ast: Node, nodes: var seq[Node]): Node =
  if node.kind == AFunction:
    var newNode: Node
    deepCopy(newNode, node.code)
    translateNode(newNode, map, ast, nodes)
    result = newNode
  else:
    result = nil

proc translateGeneric(function: Node, ast: Node, map: Table[string, Type], label: string): seq[Node] =
  assert function.kind == AFunction and function.types.kind == Generic and function.types.complex.kind == Complex
  var nodes: seq[Node] = @[]
  var value = translateNode(function, map, ast, nodes)
  result = concat(@[Node(kind: AFunction, label: label, params: function.params, types: mapGeneric(function.types, map, simple=true), code: value)], nodes)

proc simplifyGeneric(node: var Node, ast: Node): Node =
  for child in node.mitems:
    discard simplifyGeneric(child, ast)
    if child.kind == ACall and child.function.tag.kind == Generic:
      child.function.tag = child.function.tag.complex
  return node
