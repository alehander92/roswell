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


  OpcodeKind* = enum MOV, ADD, SUB, DIVL, INT, PUSHQ, POPQ, SUBQ, CALL, RET, COMMENT, INLINE, LABEL, JNE, JE, JG, JGE, JL, JLE, JMP, CMP, A

  MovSuffix* = enum MOVB, MOVW, MOVL, MOVQ

  Size* = enum SIZEBYTE, SIZEWORD, SIZEDOUBLEWORD, SIZEQUADWORD

  Opcode* = object
    case kind*: OpcodeKind
    of MOV, SUBQ:
      source*:      Operand
      destination*: Operand
      mov*:         MovSuffix
    of ADD, SUB, CMP:
      left*:        Operand
      right*:       Operand
    of INT:
      arg*:         int
    of PUSHQ, POPQ, DIVL:
      value*:       Operand
    of CALL, COMMENT, JNE, JE, JG, JGE, JL, JLE, JMP, LABEL, A:
      label*:       string
    of INLINE:
      code*:        string
    of RET: 
      discard

  OperandKind* = enum OpConstant, OpRegister, OpAddress, OpAddressRange

  Operand* = ref object
    case kind*: OperandKind
    of OpConstant:
      value*: string
    of OpRegister:
      register*: Register
    of OpAddress:
      address*: Operand
    of OpAddressRange:
      arg*: Operand
      offset*: int

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

proc reg*(register: Register): Operand =
  result = Operand(kind: OpRegister, register: register)

