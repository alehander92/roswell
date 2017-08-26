import os, strutils
import compiler

proc run =
  if paramCount() < 1:
    echo "roswell <file>"
  else:
    var code = paramStr(1)
    compileFile(code, code.rsplit('.', 2)[0])

run()
