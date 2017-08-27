import parser, typechecker, "converter", aasm, emitter, top, binary
import strutils, osproc

proc compile*(source: string, name: string): AsmModule =
  return emit(convert(typecheck(parse(source, name), TOP_ENV)))

proc compileFile*(code: string, binary: string) =
  var program = compile(readFile(code), "$1.s" % binary)
  writeFile("$1.s" % binary, toBinary(program))
  var (outp, errC) = execCmdEx("as -g -o $1.out $1.s" % binary)
  if errC == 0:
    (outp, errC) = execCmdEx("ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 -lc -o $1 $1.out" % binary)
    if errC == 0:
      echo "compiled to $1" % binary
    else:
      echo "error: $1" % outp
  else:
    echo "error: $1" % outp
