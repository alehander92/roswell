import ../aasm
import strutils, sequtils

# machine-dependent optimizer
proc asmOptimize*(module: var AsmModule) =
  # remove MOV <x> <x>
  for function in module.functions.mitems:
    function.opcodes = function.opcodes.filterIt(not (it.kind == MOV and it.source == it.destination))
    var opcodes: seq[Opcode] = @[]
    var z = 0
    while z < len(function.opcodes):
      var opcode = function.opcodes[z]
      if opcode.kind == MOV and z < len(function.opcodes) - 1 and function.opcodes[z + 1].kind == MOV and
         opcode.source == function.opcodes[z + 1].destination and opcode.destination == function.opcodes[z + 1].source:
        z += 2
      else:
        opcodes.add(opcode)
        inc z
    function.opcodes = opcodes
