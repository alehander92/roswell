import backend, parser, typechecker, "converter", aasm, triplet, terminal, emitter, c_emitter, optimizers/assembler, optimizers/c, optimizers/math, "optimizers/array", top, binary, values, evaluator, instantiation, types, ast, options, errors
import strutils, osproc

var z = 0

proc backendIndependentCompile*(source: string, name: string, directory: string, options: Options = Options(debug: false, test: false)): TripletModule =
  var ast = parse(source, name, id=z, options=options)
  inc z
  var otherDefinitions: seq[Type] = @[]
  for a, imp in ast.imports:
    assert imp.kind == AImport
    var otherCode = backendIndependentCompile(readFile("$1/$2.roswell" % [directory, imp.importLabel]), imp.importLabel, directory, options=options)
    for definition in otherCode.definitions:
      if definition.label in imp.importAliases:
        otherDefinitions.add(definition)
  var (typedAst, definitions) = typecheck(ast, otherDefinitions, TOP_ENV, options=options)
  var nonOptimized = convert(instantiate(typedAst, options=options), definitions, options=options)
  mathOptimize(nonOptimized)
  arrayOptimize(nonOptimized)
  var optimized = nonOptimized
  if not options.test:
    styledWriteLine(stdout, fgMagenta, "OPTIMIZE:\n", $optimized, resetStyle)
  result = optimized
  
proc compileToBackend*(module: TripletModule, backend: Backend, options: Options = Options(debug: false, test: false)): string =
  case backend:
  of BackendAsm:
    var res = emitter.emit(module, options=options)
    asmOptimize(res)
    return toBinary(res)
  of BackendC:
    return cText(c_emitter.emit(module, options=options))
  of BackendEvaluator:
    return ""
  of BackendCIL:
    return ""
  of BackendJVM:
    return ""
  of BackendLLVM:
    return ""

proc compile*(source: string, name: string, directory: string, backend: Backend, options: Options): string =
  var module = backendIndependentCompile(source, name, directory, options=options)
  result = compileToBackend(module, backend, options=options)

let EXTENSIONS: array[Backend, string] = ["s", "c", "roswell", "il", "class", "llvm"]

proc compileFile*(code: string, binary: string, directory: string, backend: Backend, options: Options) =
  var program = compile(readFile(code), binary, directory, backend, options)
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

proc eval*(source: string, name: string = "(script)", directory: string = "", options: Options = Options(debug: false, test: false)): RValue =
  var module = backendIndependentCompile(source, name, directory, options=options)
  result = eval(module, options=options)

proc evalFile*(code: string, directory: string, options: Options) =
  if options.test:
    try:
      discard eval(readFile(code), directory, options=options)
    except RoswellError as e:
      echo "error:\n$1" % e.msg
  else:
    discard eval(readFile(code), directory, options=options)
