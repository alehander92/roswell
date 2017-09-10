import os, strutils, parseopt2
import compiler, backend

proc run =
  if paramCount() < 1:
    echo "roswell <file> [<backend>] [--lineI"
  else:
    var code = paramStr(1)
    var backend = if paramCount() > 1: arg(paramStr(2)) else: DefaultRoswellBackend
    var z = 0
    var debug = false
    var evaluate = false
    for kind, key, val in getopt():
      if z > 1 and kind == cmdLongOption:
        if key == "debug":
          debug = true
        elif key == "eval":
          evaluate = true
      inc z
    if evaluate:
      evalFile(code)
    else:
      compileFile(code, code.rsplit('.', 2)[0], backend, debug)

run()
