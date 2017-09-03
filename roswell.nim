import os, strutils
import compiler, backend

proc run =
  if paramCount() < 1:
    echo "roswell <file> [<backend>]"
  else:
    var code = paramStr(1)
    var backend = if paramCount() > 1: arg(paramStr(2)) else: DefaultRoswellBackend
    compileFile(code, code.rsplit('.', 2)[0], backend)

run()
