import strutils, tables

type 
  Backend* = enum BackendAsm, BackendC, BackendCIL, BackendJVM, BackendLLVM

proc arg*(a: string): Backend =
  case a.toLowerAscii():
  of "asm", "assembler":
    return BackendAsm
  of "c":
    return BackendC
  of "cil", ".net":
    return BackendCIL
  of "jvm":
    return BackendJVM
  of "llvm":
    return BackendLLVM

let DefaultRoswellBackend* = BackendAsm
