import core, ast, aasm, types, env, errors
import strutils, sequtils

proc emitFunction(node: Node, module: var AsmModule): TextItem
proc emitPredefined(node: Predefined, module: var AsmModule): TextItem
proc emitLoad(params: seq[string], types: seq[Type], module: var AsmModule, function: var TextItem)

proc emit*(ast: Node): AsmModule =
  if ast.kind != AProgram:
    raise newException(RoswellError, "undefined program")
  var main: Node
  for node in ast.functions:
    if node.kind == AFunction and node.label == "main":
      main = node
      break
  if main == nil:
    raise newException(RoswellError, "undefined main")
  
  var module = AsmModule(file: ast.name, data: @[], functions: @[], labels: 0, env: aasm.newEnv(nil), active: reg(EAX))
  module.data.add(DataItem(kind: DataString, b: "\\n", label: "nl"))
  module.data.add(DataItem(kind: DataInt, a: 10, label: "i"))
  for node in ast.predefined:
    if node.called:
      module.functions.add(emitPredefined(node, module))
  for node in ast.functions:
    if node.kind != AFunction:
      raise newException(RoswellError, "undefined program")
    if node.label != "main":
      module.functions.add(emitFunction(node, module))
  module.functions.add(emitFunction(main, module))
  # echo module.functions[0].opcodes[0]
  return module

const Destinations = @[RDI, RSI]

template em(opcode: untyped): untyped =
  function.opcodes.add(`opcode`)

proc storeData(node: Node, module: var AsmModule): string =
  var item: DataItem
  if node.kind == AInt:
    item = DataItem(kind: DataInt, a: node.value)
  elif node.kind == AString:
    item = DataItem(kind: DataString, b: "$1\\n" % node.s)
  else:
    raise newException(RoswellError, "unexpected $1" % $node.kind)
  item.label = "s$1" % $len(module.data)
  module.data.add(item)
  return item.label

proc loadMov(a: Node, destination: Operand): MovSuffix =
  if destination.kind == OpRegister:
    if destination.register in {EAX, EBX, ECX, EDX}:
      echo $destination.register, a
      return MOVL
    elif destination.register in {RDI}:
      echo "LOAD:", a
      return MOVQ
  if a == nil:
    return MOVL
  elif a.kind == AInt:
    return MOVL
  elif a.kind == AString:
    return MOVQ
  elif a.kind == ABool:
    return MOVB
  else:
    return MOVL

proc emitSimple(node: Node, module: var AsmModule, function: var TextItem, j: int, into: Operand): int =
  var count = j
  var destination = if into == nil: reg(Destinations[count]) else: into
  inc count
  var mov = loadMov(node, destination)
  case node.kind:
  of AInt:
    em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: $node.value), destination: destination)
  of AFloat:
    em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: $node.f), destination: destination)
  of ABool:
    em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: $int(node.b)), destination: destination)
  of ALabel:
    em Opcode(kind: MOV, mov: mov, source: module.env[node.s], destination: destination)
  of AString:
    var s = storeData(node, module)
    em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: s), destination: destination)
    destination = reg(Destinations[count])
    inc count
    em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: $(len(node.s) + 2)), destination: destination)
  else: discard
  return count

proc activeLabel(module: var AsmModule): string =
  result = "l$1" % $(module.labels - 1)

proc nextLabel(module: var AsmModule): string =
  inc module.labels
  result = activeLabel(module)

proc emitCall(node: Node, module: var AsmModule, function: var TextItem, j: int): int =
  if j > len(Destinations):
    raise newException(RoswellError, "invalid arg")
  return emitSimple(node, module, function, j, nil)

proc emitValue(node: Node, module: var AsmModule, function: var TextItem)

proc emitBinary(op: Operator, left: Node, right: Node, module: var AsmModule, function: var TextItem) =
  case op:
  of OpMod:
    discard emitSimple(left, module, function, 0, reg(EAX))
    em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpConstant, value: "0"), destination: reg(EDX))
    discard emitSimple(right, module, function, 0, reg(EBX))
    em Opcode(kind: DIVL, value: reg(EBX))
    module.active = reg(EDX)
  of OpEq:
    var basic: Operand
    var complex: Node
    if left.kind == AInt:
      complex = right
      basic = Operand(kind: OpConstant, value: $left.value)
    elif right.kind == AInt:
      complex = left
      basic = Operand(kind: OpConstant, value: $right.value)
    else:
      complex = right
    if basic == nil:
      emitValue(left, module, function)
      basic = module.active
    emitValue(complex, module, function)
    em Opcode(kind: CMP, left: basic, right: module.active)
  else: discard

proc emitValue(node: Node, module: var AsmModule, function: var TextItem) =
  case node.kind:
  of AGroup:
    for next in node.nodes:
      emitValue(next, module, function)
  of ACall:
    if node.function.kind == ALabel:
      var j = 0
      for arg in node.args:
        j = emitCall(arg, module, function, j)
      em Opcode(kind: CALL, label: node.function.s)
    elif node.function.kind == AOperator:
      emitBinary(node.function.op, node.args[0], node.args[1], module, function)
    else:
      raise newException(RoswellError, "invalid call")
  of AReturn:
    # XXX: write
    # em Opcode(kind: RET)
    discard
  of AIf:
    emitValue(node.condition, module, function)
    var label = nextLabel(module)
    em Opcode(kind: JNE, label: label)
    emitValue(node.success, module, function)
    if node.fail != nil:
      em Opcode(kind: JMP, label: nextLabel(module))
      em Opcode(kind: LABEL, label: label)
      emitValue(node.fail, module, function)
      em Opcode(kind: LABEL, label: activeLabel(module))
    else:
      em Opcode(kind: LABEL, label: label)
  of AMember:
    raise newException(RoswellError, "unimplemented member")
  of ADefinition:
    if node.definition.kind == AAssignment:
      emitValue(node.definition.res, module, function)
  else:
    raise newException(RoswellError, "unexpected $1" % $node.kind)

proc emitBefore(module: var AsmModule, node: var TextItem) =
  var function = node
  # PUSHQ %rbp          # save the base pointer
  # MOVQ  %rsp, %rbp    # set new base pointer
  # PUSHQ %rdi          # save first argument on the stack
  # PUSHQ %rsi          # save second argument on the stack
  # PUSHQ %rdx          # save third argument on the stack
  # SUBQ  $16, %rsp     # allocate two more local variables
  # PUSHQ %rbx          # save callee-saved registers
  # PUSHQ %r12
  # PUSHQ %r13
  # PUSHQ %r14
  # PUSHQ %r15
  em Opcode(kind: PUSHQ,  value:  reg(RBP))
  em Opcode(kind: MOV,    mov: MOVQ, source: reg(RSP), destination: reg(RBP))
  em Opcode(kind: PUSHQ,  value:  reg(RDI))
  em Opcode(kind: PUSHQ,  value:  reg(RSI))
  em Opcode(kind: PUSHQ,  value:  reg(RDX))
  em Opcode(kind: SUBQ,   source: Operand(kind: OpConstant, value: "16"), destination: reg(RSP))
  em Opcode(kind: PUSHQ,  value:  reg(RBX))
  em Opcode(kind: PUSHQ,  value:  reg(R12))
  em Opcode(kind: PUSHQ,  value:  reg(R13))
  em Opcode(kind: PUSHQ,  value:  reg(R14))
  em Opcode(kind: PUSHQ,  value:  reg(R15))
  em Opcode(kind: COMMENT, label: "before\n")
  node.opcodes = function.opcodes

proc emitAfter(module: var AsmModule, node: var TextItem) =
  var function = node
  # POPQ %r15            # restore callee-saved registers
  # POPQ %r14
  # POPQ %r13
  # POPQ %r12
  # POPQ %rbx
  # MOVQ %rbp, %rsp      # reset stack to previous base pointer
  # POPQ %rbp            # recover previous base pointer
  # RET
  em Opcode(kind: COMMENT, label: "after\n")
  em Opcode(kind: POPQ,  value: reg(R15))
  em Opcode(kind: POPQ,  value: reg(R14))
  em Opcode(kind: POPQ,  value: reg(R13))
  em Opcode(kind: POPQ,  value: reg(R12))
  em Opcode(kind: POPQ,  value: reg(RBX))
  em Opcode(kind: MOV,   mov: MOVQ, source: reg(RBP), destination: reg(RSP))
  em Opcode(kind: POPQ,  value: reg(RBP))
  em Opcode(kind: RET)
  node.opcodes = function.opcodes


proc emitPredefined(node: Predefined, module: var AsmModule): TextItem =
  var res = TextItem(label: node.function, opcodes: @[])
  emitBefore(module, res)
  res.opcodes.add(Opcode(kind: INLINE, code: node.code))
  emitAfter(module, res)
  result = res


proc emitFunction(node: Node, module: var AsmModule): TextItem =
  if node.kind != AFunction:
    raise newException(RoswellError, "undefined function")
  if node.types.kind != Complex:
    raise newException(RoswellError, "undefined type")
  var res = TextItem(label: node.label, opcodes: @[])
  module.env = newEnv(module.env)
  emitBefore(module, res)
  emitLoad(node.params, node.types.args, module, res)
  emitValue(node.code, module, res)
  emitAfter(module, res)
  module.env = module.env.parent
  if node.label == "main":
    discard res.opcodes.pop()
    res.opcodes.add(Opcode(kind: INLINE, code: core.exitDefinition))
  result = res

var LOAD_LOCATIONS = @[
  reg(EAX),
  reg(EBX),
  reg(ECX),
  reg(EDX)
]

proc emitLoad(params: seq[string], types: seq[Type], module: var AsmModule, function: var TextItem) =
  for j in low(params)..high(params):
    if j >= len(LOAD_LOCATIONS):
      break
    var location = LOAD_LOCATIONS[j]
    em Opcode(kind: MOV, mov: loadMov(nil, location), source: Operand(kind: OpAddressRange, arg: reg(RBP), offset: 8 * (j + 1)), destination: location)
    module.env[params[j]] = location

