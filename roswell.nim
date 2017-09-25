import os, strutils, parseopt2
import compiler, backend, options

proc run =
  if paramCount() < 1:
    echo "roswell <file> [<backend>] [--debug --eval --test]"
  else:
    var code = paramStr(1)
    var backend = if paramCount() > 1: arg(paramStr(2)) else: DefaultRoswellBackend
    var z = 0
    var options = Options(debug: false, test: false)
    var evaluate = false
    for kind, key, val in getopt():
      if z > 1 and kind == cmdLongOption:
        if key == "debug":
          options.debug = true
        elif key == "eval":
          evaluate = true
        elif key == "test":
          options.test = true
      inc z
    if evaluate:
      evalFile(code, code.rsplit('/', 1)[0] & "/", options)
    else:
      compileFile(code, code.rsplit('.', 2)[0], code.rsplit('/', 1)[0] & "/", backend, options)

run()
