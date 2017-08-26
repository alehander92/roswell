import core, ast, aasm, types, triplet, type_env, env, errors
import strutils, sequtils

proc emitPredefined(node: Predefined, module: var AsmModule): TextItem
proc emitFunction(node: TripletFunction, module: var AsmModule): TextItem

proc emit*(a: TripletModule): AsmModule =
  var module = AsmModule(file: a.file, data: @[], functions: @[], labels: 0, env: env.newEnv[Operand](nil), active: reg(EAX))
  module.data.add(DataItem(kind: DataString, b: "\\n", label: "nl"))
  module.data.add(DataItem(kind: DataInt, a: 10, label: "i"))
  for node in a.predefined:
    if node.called:
      module.functions.add(emitPredefined(node, module))
  for node in a.functions:
    module.functions.add(emitFunction(node, module))
  return module

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

proc loadMov(node: TripletAtom, destination: Operand): MovSuffix =
  if destination.kind == OpRegister:
    if destination.register in {EAX, EBX, ECX, EDX}:
      echo $destination.register
      return MOVL
    elif destination.register in {RDI}:
      echo "LOAD:"
      return MOVQ
  if node == nil:
    return MOVL
  elif node.kind == ULabel:
    return MOVL
  elif node.kind == UConstant:
    if node.node.kind == AInt:
      return MOVL
    elif node.node.kind == AString:
      return MOVQ
    elif node.node.kind == ABool:
      return MOVB
  return MOVL

let ARG_LOCATIONS = @[
  reg(RDI),
  reg(RSI)
]

proc emitAtom(atom: TripletAtom, module: var AsmModule, function: var TextItem, destination: Operand)

proc emitF(source: TripletAtom, i: int, module: var AsmModule, function: var TextItem) =
  emitAtom(source, module, function, ARG_LOCATIONS[i])

proc emitAtom(source: Operand, module: var AsmModule, function: var TextItem, atom: TripletAtom) =
  var mov = loadMov(atom, source)
  em Opcode(kind: MOV, mov: mov, source: source, destination: reg(EAX))
  # save

proc emitAtom(atom: TripletAtom, module: var AsmModule, function: var TextItem, destination: Operand) =
  var mov = loadMov(atom, destination)
  case atom.kind:
  of ULabel:
    em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: $atom.label), destination: destination)
  of UConstant:
    case atom.node.kind:
    of AInt:
      em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: $atom.node.value), destination: destination)
    of AFloat:
      em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: $atom.node.f), destination: destination)
    of ABool:
      em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpConstant, value: $int(atom.node.b)), destination: destination)
    of AString:
      var s = storeData(atom.node, module)
      # MOVL   $19,   %edi
      # CALL   malloc
      # MOVL   $5,    (%rax)
      # MOVL   $s0,   4(%rax)

      em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpConstant, value: $(len(atom.node.s) + 15)), destination: reg(EDI))
      em Opcode(kind: CALL, label: "malloc")
      em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpConstant, value: $(len(atom.node.s) + 1)), destination: Operand(kind: OpAddress, address: reg(RAX)))
      em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpConstant, value: s), destination: Operand(kind: OpAddressRange, arg: reg(RAX), offset: 4))
    else: discard

proc emitValue(triplet: Triplet, module: var AsmModule, function: var TextItem)
proc emitLoad(index: int, memory: TripletAtom, module: var AsmModule, function: var TextItem)

proc emitBinary(triplet: Triplet, module: var AsmModule, function: var TextItem) =
  case triplet.op:
  of OpMod:
    emitAtom(triplet.left, module, function, reg(EAX))
    em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpConstant, value: "0"), destination: reg(EDX))
    emitAtom(triplet.right, module, function, reg(EBX))
    em Opcode(kind: DIVL, value: reg(EBX))
    module.active = reg(EDX)
  of OpEq:
    emitAtom(triplet.left, module, function, reg(EAX))
    emitAtom(triplet.right, module, function, reg(EBX))
    em Opcode(kind: CMP, left: reg(EAX), right: reg(EBX))
  else: discard

var AsmOperators*: array[Operator, OpcodeKind] = [
  MOV,
  MOV,
  JE,  # OpEq
  MOV,
  MOV,
  MOV,
  MOV,
  MOV,
  JNE, # OpNotEq
  JG,  # OpGt
  JGE, # OpGte
  JL,  # OpLt
  JLE, # OpLte
  MOV
]

proc emitValue(triplet: Triplet, module: var AsmModule, function: var TextItem) =
  case triplet.kind:
  of TBinary:
    emitBinary(triplet, module, function)
  of TUnary:
    discard
  of TSave:
    emitAtom(triplet.value, module, function, reg(EAX))
    # save name
  of TJump:
    em Opcode(kind: JMP, label: triplet.location)
  of TIf:
    case triplet.condition:
    of OpEq:
      em Opcode(kind: JE, label: triplet.label)
    of OpNotEq:
      em Opcode(kind: JNE, label: triplet.label)
    of OpGt:
      em Opcode(kind: JG, label: triplet.label)
    of OpGte:
      em Opcode(kind: JGE, label: triplet.label)
    of OpLt:
      em Opcode(kind: JL, label: triplet.label)
    of OpLte:
      em Opcode(kind: JLE, label: triplet.label)
    else: discard
  of TArg:
    emitF(triplet.source, triplet.i, module, function)
  of TParam:
    emitLoad(triplet.index, triplet.memory, module, function)
  of TCall:
    em Opcode(kind: CALL, label: triplet.function)
    emitAtom(reg(RAX), module, function, triplet.f)
  of TResult:
    emitAtom(triplet.a, module, function, reg(RAX))
    em Opcode(kind: JMP, label: "$1_return" % function.label)
    em Opcode(kind: RET)
  of TLabel:
    em Opcode(kind: LABEL, label: triplet.l)
  of TInline:
    em Opcode(kind: INLINE, code: triplet.code)

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
  em Opcode(kind: LABEL, label: "$1_return" % node.label)
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


proc emitFunction(node: TripletFunction, module: var AsmModule): TextItem =
  var res = TextItem(label: node.label, opcodes: @[])
  module.env = newEnv[Operand](module.env)
  emitBefore(module, res)
  for triplet in node.triplets:
    emitValue(triplet, module, res)
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

proc emitLoad(index: int, memory: TripletAtom, module: var AsmModule, function: var TextItem) =
  discard
