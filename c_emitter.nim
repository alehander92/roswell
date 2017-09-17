import ast, env, top, core, types, triplet, errors
import tables, strutils, sequtils

type
  CModule* = ref object
    debug*:       bool
    file*:        string
    definitions*: seq[CDefinition]
    functions*:   seq[CFunction]
    env*:         Env[Type]
    labels*:      int
    imports*:     seq[string]
    a*:           seq[string]

  CFunction* = object
    label*:     string
    header*:    string
    raw*:       string
    locals*:    string
    depth*:     int
    j*:         int
    args*:      string
  
  CDefinition* = object
    label*:     string
    header*:    string
    def*:       string  

proc checkArray(node: var TripletFunction, module: var TripletModule)

proc emitFunction(node: TripletFunction, module: var CModule): CFunction

proc emitDefinition(definition: Type, module: var CModule): CDefinition

proc emit*(a: TripletModule, debug: bool): CModule =
  var module = CModule(file: a.file, definitions: @[], functions: @[], labels: 0, env: newEnv[Type](nil), imports: @[], debug: debug, a: @[])
  for node in a.predefined:
    if node.called:
      module.functions.add(CFunction(label: $node.f, header: "", raw: core.cDefinitions[node.f], locals: ""))
  var m = a
  for node in m.functions.mitems:
    checkArray(node, m)
  for node in m.definitions:
    module.definitions.add(emitDefinition(node, module))
  for node in m.functions:
    module.functions.add(emitFunction(node, module))
  module.a.add(core.cDefinitions[core.PStringDefinition])
  module.imports = module.imports.concat(@["stdio.h", "stdlib.h"])
  return module


proc format(s: string, debug: bool=false): string =
  if debug:
    result = s.filterIt(it notin NewLines).join("")
  else:
    result = s
  result = result.replace("$N", "\n")

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
      of "Array", "Pointer": "$1*" % cType(typ.args[0])
      of "Function": "*$1($2)" % [cType(typ.args[^1]), typ.args[0..^2].mapIt(cType(it)).join(", ")]
      else: typ.label
  of Overload:
    cType(typ.overloads[0])
  else:
    if typ.label != nil:
      typ.label
    else:
      ""

proc cTypeDecl(typ: Type, label: string, local: bool = false): string =
  if typ.kind == Overload:
    result = cTypeDecl(typ.overloads[0], label)
  elif typ.kind == Complex and typ.label == "Pointer":
    var value = cType(typ.args[0])
    result = "$1* $2" % [value, label]
    if local and len(typ.args) == 2:
      result = "$1 = ($2*)malloc(sizeof($2) * $3)" % [result, value, typ.args[1].label]
  elif typ.kind != Complex or typ.label != "Array" and typ.label != "Function":
    result = "$1 $2" % [cType(typ), label]
  elif typ.label == "Array":
    result = "$1 $2[$3]" % [cType(typ.args[0]), label, typ.args[1].label]
  else:
    result = "$1 ($2)($3)" % [cType(typ.args[^1]), label, typ.args[0..^2].mapIt(cType(it)).join(",")]

      

proc cParam(param: string, typ: Type): string =
  result = cTypeDecl(typ, param) #"$1 $2" % [cType(typ), param]

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
  if module.debug:
    result = "$$N#line $1 \"$2\"$$N$3" % [$(node.triplets[0].location.line - 1), names[node.triplets[0].location.fileId], result]


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
      cem_locals "  $1;\n" % cTypeDecl(atom.typ, atom.label, local=true)
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
  if module.debug:
    cem "$$N#line $1 \"$2\"$$N" % [$node.location.line, names[node.location.fileId]]
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
    if node.isDeref:
      cem "*"
    ema node.destination, 0
    cem " = "
    ema node.value, 0
  of TJump:
    cem "goto $1" % node.jLocation
  of TIf:
    cem "if ("
    ema node.conditionLabel, 0
    cem " $1 1) goto $2" % [C_OPERATORS[node.condition], node.label]
  of TResult:
    cem "result0 = "
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
    if node.f.typ.kind != Simple or node.f.typ.label != "Void":
      ema node.f, 0
      cem " = "
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
    var label = module.env.getOrDefault(node.destination.label)
    if label == nil:
      module.env[node.destination.label] = node.destination.typ
      cem_locals "$1;\n" % cTypeDecl(node.destination.typ, node.destination.label, local=true)
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
  of TAddr:
    ema node.destination, 0
    cem " = "
    cem "(&"
    ema node.addressObject, 0
    cem ")"
  of TDeref:
    ema node.destination, 0
    cem " = "
    cem "(*"
    ema node.derefedObject, 0
    cem ")"
  of TInstance:
    cem ""
    # ema node.destination, 0
    # cem " = "
    # cem "($1*)malloc(sizeof($1))" % node.destination.typ.label
  of TMemberSave:
    ema node.mMember.recordObject, 0
    cem "."
    cem node.mMember.recordMember
    cem " = "
    ema node.mValue, 0
    cem ";"
    ema node.destination, 0
    cem " = "
    ema node.mMember.recordObject, 0
    cem "."
    cem node.mMember.recordMember
  of TMember:
    ema node.destination, 0
    cem " = "
    ema node.recordObject, 0
    cem "."
    cem node.recordMember
  else:
    cem ""

proc checkArray(node: var TripletFunction, module: var TripletModule) =
  if node.typ.args[^1].kind == Complex and node.typ.args[^1].label == "Array":
    node.typ.args[^1].label = "Pointer"
    # discard node.typ.args[^1].args.pop()
  for nod in module.functions.mitems:
    for e in nod.triplets.mitems:
      if e.kind == TCall and e.function == node.label:
        e.f.typ = node.typ.args[^1]
      elif e.kind == TSave and e.value.typ != nil and e.value.typ.kind == Complex and e.value.typ.label == "Pointer":
        e.destination.typ = e.value.typ
      elif e.kind == TIndexSave and e.sIndexable.typ != nil and e.sIndexable.typ.kind == Complex and e.sIndexable.typ.label == "Array":
        e.sIndexable.typ.label = "Pointer"
        # discard e.sIndexable.typ.args.pop()

proc emitFunction(node: TripletFunction, module: var CModule): CFunction =
  var function = CFunction(label: node.label, args: "", header: "", raw: "", locals: "", depth: 0, j: 0)
  module.env = newEnv[Type](module.env)
  function.header = cHead(node, module, function)
  function.depth = 1
  assert node.typ.kind == Complex
  if function.label != "main" and node.typ.args[^1] != voidType:
    function.locals.add("  $1;\n" % cTypeDecl(node.typ.args[^1], "result0"))
  for j, triplet in node.triplets[node.paramCount..^1]:
    function.j = node.paramCount + j
    var (missSemicolon, missNewline) = emitValue(triplet, module, function, function.depth)
    if not missSemicolon:
      cem ";"
    if not missNewline:
      cem "\n"
  cem "\n"
  if function.label != "main" and node.typ.args[^1] != voidType:
    cem "  return result0;"
  cem "\n}\n"
  module.env = module.env.parent
  result = function

proc emitDefinition(definition: Type, module: var CModule): CDefinition =
  result = CDefinition(label: definition.label, header: "", def: "")
  case definition.kind:
  of Record:
    result.header = "typedef struct $1 $1;" % definition.label
    result.def = "typedef struct {"
    for field, t in definition.fields:
      result.def.add("  $1;\n" % cTypeDecl(t, field))
    result.def.add("} $1;" % definition.label)
  of Enum:
    result.header = "typedef enum $1 $1;" % definition.label
    result.def = "typedef enum $1 {$2};" % [definition.label, definition.variants.join(", ")]
  of Data:
    result.header = "typedef struct $1Data $1Data;" % definition.label
    result.def = "typedef struct $1Data {\n  $1Enum active;\n  union branches {\n"
    for z, branch in definition.branches:
      result.def.add("    struct B$1 {\n" % $z)
      for a, t in branch:
        result.def.add("      $1;\n" % cTypeDecl(t, "t$1" % $a))
      result.def.add("    }\n")
    result.def.add("  }\n} $1Data;" % definition.label)
  else:
    discard

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
  result.add(module.definitions.mapIt(it.def).join("\n\n"))
  result.add(module.functions.filterIt(it.label != "main").mapIt("$1;" % it.header).join("\n"))
  result.add(format(module.functions.mapIt(cDef(it)).join("\n\n"), debug=module.debug))

