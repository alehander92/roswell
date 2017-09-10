import core, ast, aasm, types, triplet, type_env, env, errors
import strutils, sequtils, tables

proc emitPredefined(node: Predefined, module: var AsmModule): TextItem
proc emitFunction(node: TripletFunction, module: var AsmModule): TextItem

proc emit*(a: TripletModule, debug: bool=false): AsmModule =
  var module = AsmModule(file: a.file, data: @[], functions: @[], labels: 0, debug: debug, env: env.newEnv[Operand](nil))
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

proc freeRegister(function: var TextItem, size: Size): (bool, Register) =
  for r in SIZE_REGISTERS[size]:
    if function.available[r]:
      return (true, r)
  return (false, RAX)

proc loadLocation(function: var TextItem, module: AsmModule, label: string, size: Size, arrayCount: int): Operand =
  var location = module.env.getOrDefault(label)
  if location == nil:
    if arrayCount == -1:
      var (free, register) = freeRegister(function, size)
      if free:
        location = reg(register)
        function.available[register] = false
        module.env[label] = location
        result = location
        return
    location = Operand(kind: OpAddressRange, offset: -function.index, arg: reg(RBP))
    if arrayCount == -1:
      function.index += OFFSETS[size]
    else:
      function.index += OFFSETS[size] * arrayCount
    module.env[label] = location
  result = location

proc loadSize(typ: Type): Size

proc loadSize(operand: Operand): Size =
  if operand.kind == OpRegister:
    for size in @[SIZEBYTE, SIZEWORD, SIZEDOUBLEWORD, SIZEQUADWORD]:
      if operand.register in SIZE_REGISTERS[size]:
        return size
  else:
    return SIZEQUADWORD

proc translate(node: TripletAtom, module: AsmModule, function: var TextItem): Operand =
  case node.kind:
  of ULabel:
    var size = loadSize(node.typ)
    result = loadLocation(function, module, node.label, size, -1)
  of UConstant:
    if node.node.kind == AInt:
      result = Operand(kind: OpInt, i: node.node.value)
    else:
      var value = case node.node.kind:
      of ABool:
        if node.node.b: "1" else: "0"
      of AFloat:
        $node.node.f
      of AString:
        node.node.s
      else:
        ""
      result = Operand(kind: OpConstant, value: value)

proc loadSize(typ: Type): Size =
  case typ.kind:
  of Simple:
    case typ.label:
    of "Int":
      return SIZEDOUBLEWORD
    of "Float":
      return SIZEQUADWORD
    of "String":
      return SIZEDOUBLEWORD
    of "Bool":
      return SIZEBYTE
    else:
      return SIZEDOUBLEWORD
  else:
    return SIZEDOUBLEWORD

# XXX: hack around compile time kind
proc loadMov(size: Size, destination: Operand, cell: bool = false): MovSuffix =
  if cell:
    return MOVLEA
  else:
    return MovSuffix(int(size))

let ARG_LOCATIONS = @[
  reg(RDI),
  reg(RSI),
  reg(RDX),
  reg(RCX),
  reg(R8),
  reg(R9)
]

proc emitAtom(atom: TripletAtom, module: var AsmModule, function: var TextItem, destination: Operand, cell: bool = false, q: bool = false)

proc emitAtom(source: Operand, module: var AsmModule, function: var TextItem, destination: Operand, cell: bool = false)

proc emitF(source: TripletAtom, i: int, module: var AsmModule, function: var TextItem) =
  if source.typ.kind == Complex and source.typ.label == "Array":
    em Opcode(kind: LEA, source: translate(source, module, function), destination: reg(RAX))
    emitAtom(reg(RAX), module, function, ARG_LOCATIONS[i])
  else:
    emitAtom(source, module, function, ARG_LOCATIONS[i], q=true)

proc emitAtom(source: TripletAtom, module: var AsmModule, function: var TextItem, destination: TripletAtom, cell: bool = false) =
  if destination.kind != ULabel: return
  var size = loadSize(destination.typ)
  var mov = loadMov(size, reg(SI))
  var dest = loadLocation(function, module, destination.label, size, -1)
  emitAtom(source, module, function, dest, cell=cell)

proc emitAtom(source: Operand, module: var AsmModule, function: var TextItem, destination: Operand, cell: bool = false) =
  var size = loadSize(source)
  var mov = loadMov(size, source, cell=cell)
  if source.kind in {OpAddress, OpAddressRange} and destination.kind in {OpAddress, OpAddressRange}:
    em Opcode(kind: MOV, mov: mov, source: source, destination: reg(SIZE_REGISTERS[size][0])) 
    em Opcode(kind: MOV, mov: mov, source: reg(SIZE_REGISTERS[size][0]), destination: destination)
  else:
    em Opcode(kind: MOV, mov: mov, source: source, destination: destination)

proc emitAtom(source: Operand, module: var AsmModule, function: var TextItem, atom: TripletAtom, cell: bool = false) =
  if atom.kind != ULabel: return
  var size = loadSize(atom.typ)
  var location = loadLocation(function, module, atom.label, size, -1)
  emitAtom(source, module, function, location)
  # em Opcode(kind: MOV, mov: mov, source: source, destination: location)
  # save

proc emitAtom(atom: TripletAtom, module: var AsmModule, function: var TextItem, destination: Operand, cell: bool = false, q: bool = false) =
  # emitAtom moves values from source to destination
  # the destination might be passed as an arg
  # if it's not we move the value to a register or a place on the stack depending on its type
  # we add the suffix of move based on the type
  # an env holds the locations of the local variables
  # an array holds if a register is available
  # an index holds the next free stack
  var size = if q: SIZEQUADWORD else: loadSize(atom.typ)
  var mov = loadMov(size, destination, cell=cell)
  case atom.kind:
  of ULabel:
    var location = loadLocation(function, module, atom.label, size, -1)
    emitAtom(location, module, function, destination)
  of UConstant:
    case atom.node.kind:
    of AInt:
      em Opcode(kind: MOV, mov: mov, source: Operand(kind: OpInt, i: atom.node.value), destination: destination)
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

      em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpInt, i: len(atom.node.s) + 15), destination: reg(EDI))
      em Opcode(kind: CALL, label: "malloc")
      em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpInt, i: len(atom.node.s) + 1), destination: Operand(kind: OpAddress, address: reg(RAX)))
      em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpConstant, value: s), destination: Operand(kind: OpAddressRange, offset: 4, arg: reg(RAX)))
      em Opcode(kind: MOV, mov: mov, source: reg(RAX), destination: destination)
    else: discard

proc emitValue(triplet: Triplet, module: var AsmModule, function: var TextItem)
proc emitLoad(index: int, memory: TripletAtom, module: var AsmModule, function: var TextItem)

proc emitBinary(triplet: Triplet, module: var AsmModule, function: var TextItem) =
  var r: Operand = nil
  case triplet.op:
  of OpMod:
    emitAtom(triplet.left, module, function, reg(EAX))
    em Opcode(kind: MOV, mov: MOVL, source: Operand(kind: OpInt, i: 0), destination: reg(EDX))
    emitAtom(triplet.right, module, function, reg(EBX))
    em Opcode(kind: DIVL, value: reg(EBX))
    r = reg(EDX)
  of OpEq:
    var left = translate(triplet.left, module, function)
    var right = reg(EBX)
    if triplet.right.kind == UConstant:
      emitAtom(triplet.right, module, function, right)
    else:
      right = translate(triplet.right, module, function)
    em Opcode(kind: CMP, left: left, right: right)
  of OpAdd:
    emitAtom(triplet.left, module, function, reg(EDX))
    emitAtom(triplet.right, module, function, reg(EAX))
    em Opcode(kind: ADD, left: reg(EDX), right: reg(EAX))
    emitAtom(reg(EAX), module, function, triplet.destination)
  else: discard
  if r != nil:
    emitAtom(r, module, function, triplet.destination)
  else: discard

proc z(indexable: TripletAtom, index: TripletAtom, size: Size, module: var AsmModule, function: var TextItem): Operand =
  var register = reg(SIZE_REGISTERS[size][0])
  emitAtom(index, module, function, register)
  result = Operand(kind: OpAddressRange, offset: 0, arg: translate(indexable, module, function), index: register, indexSize: size)

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
    if triplet.isDeref:
      emitAtom(triplet.destination, module, function, reg(RAX))
      emitAtom(triplet.value, module, function, Operand(kind: OpAddress, address: reg(RAX)))
    else:
      emitAtom(triplet.value, module, function, triplet.destination)
  of TJump:
    em Opcode(kind: JMP, label: triplet.jLocation)
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
    var size = loadSize(triplet.f.typ)
    emitAtom(reg(SIZE_REGISTERS[size][0]), module, function, triplet.f)
  of TResult:
    var size = loadSize(triplet.destination.typ)
    emitAtom(triplet.destination, module, function, reg(SIZE_REGISTERS[size][0]))
    em Opcode(kind: JMP, label: "$1_return" % function.label)
  of TLabel:
    em Opcode(kind: LABEL, label: triplet.l)
  of TInline:
    em Opcode(kind: INLINE, code: core.asmDefinitions[triplet.code])
  of TIndex:
    var t = translate(triplet.indexable, module, function)
    var size = loadSize(triplet.destination.typ)
    assert t.kind == OpAddressRange and t.index == nil and t.arg.kind == OpRegister and t.arg.register == RBP
    # XXX: hack
    if function.label != "main":
      emitAtom(t, module, function, reg(RAX))
      emitAtom(Operand(kind: OpAddressRange, offset: -OFFSETS[size] * triplet.iindex.node.value, arg: reg(RAX)), module, function, triplet.destination)
    elif triplet.iindex.kind == UConstant and triplet.iindex.node.kind == AInt:
      emitAtom(Operand(kind: OpAddressRange, offset: t.offset - OFFSETS[size] * triplet.iindex.node.value, arg: reg(RBP)), module, function, triplet.destination)
    else:
      var y = z(triplet.indexable, triplet.iindex, size, module, function)
      emitAtom(y, module, function, triplet.destination)
  of TArray:
    assert triplet.destination.typ.kind == Complex
    var size = loadSize(triplet.destination.typ.args[0])
    discard loadLocation(function, module, triplet.destination.label, size, triplet.arrayCount)
    # echo "env"
    # for b, c in module.env.locations:
    #   if c.kind == OpAddressRange:
    #     echo b, " ", c.offset
    #   elif c.kind == OpRegister:
    #     echo b, " ", c.register
  of TIndexSave:
    echo "env"
    for b, c in module.env.locations:
      if c.kind == OpAddressRange:
        echo b, " ", c.offset
      elif c.kind == OpRegister:
        echo b, " ", c.register
    var sIndexable = translate(triplet.sIndexable, module, function)
    var size = loadSize(triplet.destination.typ)
    assert sIndexable.kind == OpAddressRange and sIndexable.index == nil and sIndexable.arg.kind == OpRegister and sIndexable.arg.register == RBP
    if triplet.sIndex.kind == UConstant and triplet.sIndex.node.kind == AInt:
      var target = Operand(kind: OpAddressRange, offset: sIndexable.offset - OFFSETS[size] * triplet.sIndex.node.value, arg: reg(RBP))
      emitAtom(triplet.sValue, module, function, target)
      emitAtom(target, module, function, triplet.destination)
    else:
      var sIndex = z(triplet.sIndexable, triplet.sIndex, size, module, function)
      emitAtom(triplet.sValue, module, function, sIndex)
      emitAtom(sIndex, module, function, triplet.destination)
  of TAddr:
    emitAtom(triplet.addressObject, module, function, triplet.destination, cell=true)
  of TDeref:
    emitAtom(triplet.derefedObject, module, function, reg(RAX))
    emitAtom(Operand(kind: OpAddress, address: reg(RAX)), module, function, triplet.destination)

proc emitBefore(arg: TripletFunction, module: var AsmModule, node: var TextItem) =
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
  var opcodes = function.opcodes
  function.opcodes = @[]
  em Opcode(kind: PUSHQ,  value:  reg(RBP))
  em Opcode(kind: MOV,    mov: MOVQ, source: reg(RSP), destination: reg(RBP))
  for j in 0..<arg.paramCount:
    if j >= len(ARG_LOCATIONS):
      raise newException(RoswellError, "too many args")
    em Opcode(kind: PUSHQ,  value:  ARG_LOCATIONS[j])
  em Opcode(kind: SUBQ,   source: Operand(kind: OpInt, i: function.index), destination: reg(RSP))
  em Opcode(kind: PUSHQ,  value:  reg(RBX))
  em Opcode(kind: PUSHQ,  value:  reg(R12))
  em Opcode(kind: PUSHQ,  value:  reg(R13))
  em Opcode(kind: PUSHQ,  value:  reg(R14))
  em Opcode(kind: PUSHQ,  value:  reg(R15))
  em Opcode(kind: COMMENT, label: "before\n")
  function.opcodes = concat(function.opcodes, opcodes)
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
  res.opcodes.add(Opcode(kind: INLINE, code: core.asmDefinitions[node.f]))
  res.index = 16
  emitBefore(TripletFunction(paramCount: 2, locals: 2), module, res)
  emitAfter(module, res)
  result = res


var Available: array[Register, bool] = [
  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false
]

proc emitFunction(node: TripletFunction, module: var AsmModule): TextItem =
  var res = TextItem(label: node.label, opcodes: @[], available: Available, index: 8 * node.paramCount + 8)
  module.env = newEnv[Operand](module.env)
  for triplet in node.triplets:
    emitValue(triplet, module, res)
  emitBefore(node, module, res)
  emitAfter(module, res)
  module.env = module.env.parent
  if node.label == "main":
    discard res.opcodes.pop()
    res.opcodes.add(Opcode(kind: INLINE, code: core.asmDefinitions[core.PExitDefinition]))
  result = res

var LOAD_LOCATIONS = @[
  reg(EAX),
  reg(EBX),
  reg(ECX),
  reg(EDX)
]

proc emitLoad(index: int, memory: TripletAtom, module: var AsmModule, function: var TextItem) =
  if memory.kind == ULabel:
    # if memory.typ.kind != Complex or memory.typ.label != "Array":
    module.env[memory.label] = Operand(kind: OpAddressRange, offset: -8 * (index + 1), arg: reg(RBP))
    # else:
    #   var size = loadSize(memory.typ.args[0])
    #   var location = loadLocation(function, module, memory.label, size, parseInt(memory.typ.args[1].label))
    #   var cell: bool = false
    #   emitAtom(Operand(kind: OpAddressRange, offset: -8 * (index + 1), arg: reg(RBP)), module, function, location, cell=cell)
