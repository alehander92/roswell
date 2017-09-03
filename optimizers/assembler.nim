import ../aasm
import strutils, sequtils

# machine-dependent optimizer
proc asmOptimize*(module: var AsmModule) =
  # remove MOV <x> <x>
  for function in module.functions.mitems:
    function.opcodes = function.opcodes.filterIt(not (it.kind == MOV and it.source == it.destination))
