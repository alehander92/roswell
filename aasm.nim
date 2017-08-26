import env, errors
import tables, strutils

type
  AsmModule* = ref object
    file*:      string
    data*:      seq[DataItem]
    functions*: seq[TextItem]
    labels*:    int
    env*:       Env[Operand]
    active*:    Operand

  DataItemKind* = enum DataInt, DataString

  DataItem* = object
    label*: string
    case kind*: DataItemKind
    of DataInt:
      a*: int
    of DataString:
      b*: string

  TextItem* = object
    label*:   string
    opcodes*: seq[Opcode]

  Register* = enum AL, CL, DL, EAX, EBX, ESI, R10, R11, R12, R13, R14, R15, RBP, RSP, RBX, RDI, RSI, RDX, ECX, EDX, B, C

  OpcodeKind* = enum MOV, ADD, SUB, DIVL, INT, PUSHQ, POPQ, SUBQ, CALL, RET, COMMENT, INLINE, LABEL, JNE, JMP, CMP, A

  MovSuffix* = enum MOVQ, MOVB, MOVL, MOVW

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
    of CALL, COMMENT, JNE, JMP, LABEL, A:
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


proc reg*(register: Register): Operand =
  return Operand(kind: OpRegister, register: register)

