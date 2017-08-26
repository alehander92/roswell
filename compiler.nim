import parser, typechecker, "converter", aasm, emitter, top, binary
import strutils, osproc

proc compile*(source: string): AsmModule =
  return emit(convert(typecheck(parse(source), TOP_ENV)))

proc compileFile*(code: string, binary: string) =
  var program = compile(readFile(code))
  writeFile("$1.s" % binary, toBinary(program))
  let (outp, errC) = execCmdEx("as -o $1.out $1.s" % binary)
  if errC == 0:
    discard execCmdEx("ld -o $1 $1.out" % binary)
