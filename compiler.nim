import backend, parser, typechecker, "converter", aasm, triplet, emitter, c_emitter, top, binary
import strutils, osproc

proc backendIndependentCompile*(source: string, name: string): TripletModule =
  return convert(typecheck(parse(source, name), TOP_ENV))

proc compileToBackend*(module: TripletModule, backend: Backend): string =
  case backend:
  of BackendAsm:
    return toBinary(emitter.emit(module))
  of BackendC:
    return cText(c_emitter.emit(module))
  of BackendCIL:
    return ""
  of BackendJVM:
    return ""
  of BackendLLVM:
    return ""

proc compile*(source: string, name: string, backend: Backend): string =
  var module = backendIndependentCompile(source, name)
  result = compileToBackend(module, backend)

let EXTENSIONS: array[Backend, string] = ["s", "c", "il", "class", "llvm"]

proc compileFile*(code: string, binary: string, backend: Backend) =
  var program = compile(readFile(code), "$1.s" % binary, backend)
  writeFile("$1.$2" % [binary, EXTENSIONS[backend]], program)
  if backend == BackendAsm:
    var (outp, errC) = execCmdEx("as -g -o $1.out $1.s" % binary)
    if errC == 0:
      (outp, errC) = execCmdEx("ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 -lc -o $1 $1.out" % binary)
      if errC == 0:
        echo "compiled to $1" % binary
      else:
        echo "error: $1" % outp
    else:
      echo "error: $1" % outp
  elif backend == BackendC:
    var (outp, errC) = execCmdEx("gcc -g -o $1 $1.c" % binary)
    if errC == 0:
      echo "compiled to $1" % binary

