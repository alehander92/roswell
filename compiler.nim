import backend, parser, typechecker, "converter", aasm, triplet, terminal, emitter, c_emitter, optimizers/assembler, optimizers/c, optimizers/math, "optimizers/array", top, binary, values, evaluator
import strutils, osproc

proc backendIndependentCompile*(source: string, name: string, debug: bool=false): TripletModule =
  var nonOptimized = convert(typecheck(parse(source, name, id=0), TOP_ENV), debug=debug)
  mathOptimize(nonOptimized)
  arrayOptimize(nonOptimized)
  var optimized = nonOptimized
  styledWriteLine(stdout, fgMagenta, "OPTIMIZE:\n", $optimized, resetStyle)
  result = optimized

proc compileToBackend*(module: TripletModule, backend: Backend, debug: bool=false): string =
  case backend:
  of BackendAsm:
    var res = emitter.emit(module, debug=debug)
    asmOptimize(res)
    return toBinary(res)
  of BackendC:
    return cText(c_emitter.emit(module, debug=debug))
  of BackendCIL:
    return ""
  of BackendJVM:
    return ""
  of BackendLLVM:
    return ""

proc compile*(source: string, name: string, backend: Backend, debug: bool): string =
  var module = backendIndependentCompile(source, name, debug=debug)
  result = compileToBackend(module, backend, debug=debug)

let EXTENSIONS: array[Backend, string] = ["s", "c", "il", "class", "llvm"]

proc compileFile*(code: string, binary: string, backend: Backend, debug: bool) =
  var program = compile(readFile(code), binary, backend, debug)
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

proc eval*(source: string, name: string = "(script)"): RValue =
  var module = backendIndependentCompile(source, name, debug=true)
  result = eval(module)

proc evalFile*(code: string) =
  echo eval(readFile(code))
