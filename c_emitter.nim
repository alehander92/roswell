import ast, env, top, core, types, triplet, errors
import tables, strutils, sequtils

type
  CModule* = ref object
    file*:      string
    functions*: seq[CFunction]
    env*:       Env[Type]
    labels*:    int
    imports*:   seq[string]
    a*:         seq[string]

  CFunction* = object
    label*:     string
    header*:    string
    raw*:       string
    locals*:    string
    depth*:     int
    j*:         int
    args*:      string

proc emitFunction(node: TripletFunction, module: var CModule): CFunction

proc emit*(a: TripletModule): CModule =
  var module = CModule(file: a.file, functions: @[], labels: 0, env: newEnv[Type](nil), imports: @[], a: @[])
  for node in a.predefined:
    if node.called:
      module.functions.add(CFunction(label: $node.f, header: "", raw: core.cDefinitions[node.f], locals: ""))
  for node in a.functions:
    module.functions.add(emitFunction(node, module))
  module.a.add(core.cDefinitions[core.PStringDefinition])
  module.imports = module.imports.concat(@["stdio.h", "stdlib.h"])
  return module

template cem(s: untyped): untyped =
  function.raw.add(`s`)

template cem_locals(s: untyped): untyped =
  function.locals.add(`s`)

template ema(s: untyped, depth: untyped): untyped =
  emitAtom(`s`, module, function, `depth`)

proc cType(typ: Type): string =
  result = case typ.kind:
  of Simple:
    case typ.label:
    of "Int": "int"
    of "String": "RoswellString*"
    of "Float": "float"
    of "Bool": "int"
    of "Void": "void"
    else: typ.label
  of Complex:
    case typ.label:
      of "Array": "$1*" % cType(typ.args[0])
      else: typ.label
  else:
    typ.label

proc cParam(param: string, typ: Type): string =
  result = "$1 $2" % [cType(typ), param]

proc cHead(node: TripletFunction, module: var CModule, function: var CFunction): string =
  var params: seq[string] = @[]
  var types: seq[Type] = @[]
  for n in node.triplets[0..(node.paramCount - 1)]:
    assert n.memory.kind == ULabel
    params.add(n.memory.label)
    types.add(n.memory.typ)
    module.env[n.memory.label] = n.memory.typ

  assert node.typ.kind == Complex
  result = "$1 $2($3)" % [
    if function.label != "main": cType(node.typ.args[^1]) else: "int",
    node.label,
    (0..(node.paramCount - 1)).mapIt(cParam(params[it], types[it])).join(", ")
  ]

let C_OPERATORS: array[Operator, string] = [
  "&&",   # OpAnd
  "||",   # OpOr
  "==",   # OpEq
  "%",    # OpMod
  "+",    # OpAdd
  "-",    # OpSub
  "*",    # OpMul
  "/",    # OpDiv
  "!=",   # OpNotEq
  ">",    # OpGt
  ">=",   # OpGte
  "<",    # OpLt
  "<=",   # OpLte
  "^"     # OpXor
]

proc emitAtom(atom: TripletAtom, module: var CModule, function: var CFunction, depth: int) =
  cem repeat("  ", depth)
  case atom.kind:
  of ULabel:
    var label = module.env.getOrDefault(atom.label)
    if label == nil:
      module.env[atom.label] = atom.typ
      if atom.typ.kind != Complex or atom.typ.label != "Array":
        cem_locals "  $1 $2;\n" % [cType(atom.typ), atom.label]
      else:
        cem_locals "  $1 $2[$3];\n" % [cType(atom.typ.args[0]), atom.label, atom.typ.args[1].label]
    cem atom.label
  of UConstant:
    case atom.node.kind:
      of AInt:
        cem $atom.node.value
      of AString:
        cem "roswell_string(\"$1\", $2)" % [atom.node.s, $len(atom.node.s)]
      of AFloat:
        cem $atom.node.f
      of ABool:
        cem (if atom.node.b: "1" else: "0")
      else:
        cem ""

proc emitValue(node: Triplet, module: var CModule, function: var CFunction, depth: int): (bool, bool) =
  var offset = repeat("  ", depth)
  cem offset
  result = (false, false)
  case node.kind:
  of TBinary:
    ema node.destination, 0
    cem " = "
    ema node.left, 0
    cem " $1 " % C_OPERATORS[node.op]
    ema node.right, 0
  of TUnary:
    ema node.destination, 0
    cem " = $1" % C_OPERATORS[node.unaryOp]
  of TSave:
    ema node.destination, 0
    cem " = "
    ema node.value, 0
  of TJump:
    cem "goto $1" % node.location
  of TIf:
    cem "if ("
    ema node.conditionLabel, 0
    cem " $1 1) goto $2" % [C_OPERATORS[node.condition], node.label]
  of TResult:
    cem "result = "
    ema node.destination, 0
  of TArg:
    var raw = function.raw
    function.raw = ""
    cem "\n"
    ema node.source, 0
    function.args.add(function.raw)
    function.raw = raw
    result = (true, true) # miss ; \n
  of TCall:
    var args = function.args.splitLines()[^node.count..^1]
    cem "$1($2)" % [node.function, args.join(", ")]
  of TInline:
    cem core.cDefinitions[node.code]
    result = (true, true) # miss ; \n
  of TLabel:
    cem "$1:" % node.l
    result = (true, false) # miss ;
  of TIndex:
    ema node.destination, 0
    cem " = "
    ema node.indexable, 0
    cem "["
    ema node.iindex, 0
    cem "]"
  of TArray:
    assert node.destination.kind == ULabel
    assert node.destination.typ.kind == Complex
    module.env[node.destination.label] = node.destination.typ
    cem_locals "  $1 $2[$3];\n" % [cType(node.destination.typ.args[0]), node.destination.label, $node.arrayCount]
    result = (true, true) # miss ; \n    
  of TIndexSave:
    ema node.sIndexable, 0
    cem "["
    ema node.sIndex, 0
    cem "] = "
    ema node.sValue, 0
    cem ";"
    ema node.destination, 0
    cem " = "
    ema node.sIndexable, 0
    cem "["
    ema node.sIndex, 0
    cem "]"
  else:
    cem ""

proc emitFunction(node: TripletFunction, module: var CModule): CFunction =
  var function = CFunction(label: node.label, args: "", header: "", raw: "", locals: "", depth: 0, j: 0)
  module.env = newEnv[Type](module.env)
  function.header = cHead(node, module, function)
  function.depth = 1
  assert node.typ.kind == Complex
  if function.label != "main" and node.typ.args[^1] != voidType:
    function.locals.add("  $1 result;\n" % cType(node.typ.args[^1]))
  for j, triplet in node.triplets[node.paramCount..^1]:
    function.j = node.paramCount + j
    var (missSemicolon, missNewline) = emitValue(triplet, module, function, function.depth)
    if not missSemicolon:
      cem ";"
    if not missNewline:
      cem "\n"
  cem "\n"
  if function.label != "main" and node.typ.args[^1] != voidType:
    cem "  return result;"
  cem "\n}\n"
  module.env = module.env.parent
  result = function

proc cImport(imp: string): string =
  result = "#include <$1>" % imp

proc cDef(it: CFunction): string =
  if len(it.header) > 0:
    result = "$1 {\n$2\n$3" % [it.header, it.locals, it.raw]
  else:
    result = it.raw

proc cText*(module: CModule): string =
  result = ""
  result.add(module.imports.mapIt(cImport(it)).join("\n"))
  result.add("\n\n")
  result.add(module.a.join("\n"))
  result.add(module.functions.mapIt(cDef(it)).join("\n\n"))


