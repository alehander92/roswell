import env, errors
import tables, strutils

type
  Register* = enum 
    RAX, RCX, RDX, RBX, RSI, RDI, RSP, RBP, R8, R9, R10, R11, R12, R13, R14, R15,
    EAX, ECX, EDX, EBX, ESI, EDI, ESP, EBP, R8D, R9D, R10D, R11D, R12D, R13D, R14D, R15D,
    AX, CX, DX, BX, SI, DI, SP, BP, R8W, R9W, R10W, R11W, R12W, R13W, R14W, R15W,
    AL, CL, DL, BL, SIL, DIL, SPL, BPL, R8B, R9B, R10B, R11B, R12B, R13B, R14B, R15B

  AsmModule* = ref object
    file*:      string
    data*:      seq[DataItem]
    functions*: seq[TextItem]
    env*:       Env[Operand]
    labels*:    int

  DataItemKind* = enum DataInt, DataString

  DataItem* = object
    label*: string
    case kind*: DataItemKind
    of DataInt:
      a*: int
    of DataString:
      b*: string

  TextItem* = object
    label*:     string
    opcodes*:   seq[Opcode]
    available*: array[Register, bool]
    index*:     int


  OpcodeKind* = enum 
    MOV, LEA,
    ADD, SUB, SUBQ, DIVL, MUL, IMUL,
    INT, PUSHQ, POPQ,
    CALL, RET, COMMENT, INLINE,
    LABEL, JNE, JE, JG, JGE, JL, JLE, JMP, CMP, A

  MovSuffix* = enum MOVB, MOVW, MOVL, MOVQ, MOVLEA

  Size* = enum SIZEBYTE, SIZEWORD, SIZEDOUBLEWORD, SIZEQUADWORD

  Opcode* = object
    case kind*: OpcodeKind
    of MOV, SUBQ, LEA:
      source*:      Operand
      destination*: Operand
      mov*:         MovSuffix
    of ADD, SUB, IMUL, CMP:
      left*:        Operand
      right*:       Operand
    of INT:
      arg*:         int
    of PUSHQ, POPQ, DIVL, MUL:
      value*:       Operand
    of CALL, COMMENT, JNE, JE, JG, JGE, JL, JLE, JMP, LABEL, A:
      label*:       string
    of INLINE:
      code*:        string
    of RET: 
      discard

  OperandKind* = enum OpConstant, OpInt, OpRegister, OpAddress, OpAddressRange

  Operand* = ref object
    case kind*: OperandKind
    of OpConstant:
      value*: string
    of OpInt:
      i*: int
    of OpRegister:
      register*: Register
    of OpAddress:
      address*: Operand
    of OpAddressRange:
      arg*:       Operand
      offset*:    int
      index*:     Operand
      indexSize*: Size


  AsmEnv* = ref object
    locations*:  Table[string, Operand]
    parent*:     AsmEnv
    top*:        AsmEnv

let SIZE_REGISTERS*: array[Size, seq[Register]] = [
  @[AL, CL, DL, BL, SIL, DIL, SPL, BPL, R8B, R9B, R10B, R11B, R12B, R13B, R14B, R15B], # SIZEBYTE
  @[AX, CX, DX, BX, SI, DI, SP, BP, R8W, R9W, R10W, R11W, R12W, R13W, R14W, R15W], # SIZEWORD
  @[EAX, ECX, EDX, EBX, ESI, EDI, ESP, EBP, R8D, R9D, R10D, R11D, R12D, R13D, R14D, R15D], # SIZEDOUBLEWORD
  @[RAX, RCX, RDX, RBX, RSI, RDI, RSP, RBP, R8, R9, R10, R11, R12, R13, R14, R15] # SIZEQUADWORD  
]

let OFFSETS*: array[Size, int] = [1, 2, 4, 8]

proc reg*(register: Register): Operand =
  result = Operand(kind: OpRegister, register: register)

proc `==`*(left: Operand, right: Operand): bool =
  if cast[pointer](left) == nil:
    return cast[pointer](right) == nil
  if cast[pointer](right) == nil:
    return cast[pointer](left) == nil
  if left.kind != right.kind:
    return false
  else:
    case left.kind:
    of OpConstant:
      return left.value == right.value
    of OpInt:
      return left.i == right.i
    of OpRegister:
      return left.register == right.register
    of OpAddress:
      return left.address == right.address
    of OpAddressRange:
      if left.index == nil or right.index == nil:
        if left.index != nil or right.index != nil:
          return false
        return left.arg == right.arg and left.offset == right.offset
      else:
        return left.arg == right.arg and left.offset == right.offset and
               left.index == right.index and left.indexSize == right.indexSize
