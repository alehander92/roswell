import aasm, helpers
import strutils, sequtils


proc toBinary*(b: AsmModule): string
proc toBinary(node: DataItem): string
proc toBinary(node: TextItem): string
proc toBinary(opcode: Opcode): string
proc toBinary(operand: Operand): string

proc toBinary*(b: AsmModule): string =
  result = ""
  result.add(".file    \"$1\"\n" % b.file)
  result.add(".data\n$1\n" % b.data.mapIt(toBinary(it)).join("\n"))
  result.add(".text\n\n$1\n" % b.functions.mapIt(toBinary(it)).join("\n"))

proc toBinary(node: DataItem): string =
  var a: string
  var b: string
  if node.kind == DataInt:
    a = ".long"
    b = $node.a
  else:
    a = ".string"
    b = "\"$1\"" % node.b
  result = "$1:\n    $2 $3" % [node.label, a, b]

proc toBinary(node: TextItem): string =
  var label = if node.label == "main": "_start" else: node.label
  result = ".global $1\n$1:\n$2\n" % [label, node.opcodes.mapIt(toBinary(it)).join("\n")]

proc toBinary(operand: Operand): string =
  result = case operand.kind:
  of OpConstant:
    "$$$1" % operand.value
  of OpInt:
    var h = "0x$1" % toHex(abs(operand.i)).strip(chars={'0'}, trailing=false)
    if len(h) == 2:
      h = "0x0"
    elif operand.i < 0:
      h = "-$1" % h
    "$$$1" % h
  of OpRegister:
    "%$1" % toLowerAscii($operand.register)
  of OpAddress:
    "($1)" % toBinary(operand.address)
  of OpAddressRange:
    var h = "0x$1" % toHex(abs(operand.offset)).strip(chars={'0'}, trailing=false).toLowerAscii()
    if len(h) == 2:
      h = ""
    if operand.offset < 0 and len(h) > 0:
      h = "-$1" % h
    if operand.index == nil:
      "$1($2)" % [h, toBinary(operand.arg)]
    else:
      var index = toBinary(operand.index)
      if index[0] == '$':
        index = index[1..^1]
      var arg = ""
      var offset = ""
      if operand.arg.kind == OpAddressRange and operand.arg.index == nil:
        arg = toBinary(operand.arg.arg)
        offset = "0x$1" % toHex(abs(operand.arg.offset)).strip(chars={'0'}, trailing=false).toLowerAscii()
        if operand.arg.offset < 0 and len(offset) > 2:
          offset = "-$1" % offset
      else:
        arg = toBinary(operand.arg)
        offset = h
      if offset == "0x0" or offset == "0x":
        offset = ""
      "$1($2, $3, $4)" % [offset, arg, index, $OFFSETS[operand.indexSize]]

proc toBinary(opcode: Opcode): string =
  if opcode.kind == COMMENT:
    return repeat("    ", 1) & "#$1" % opcode.label
  elif opcode.kind == INLINE:
    return opcode.code.splitLines().mapIt(repeat("    ", 1) & it).join("\n")
  elif opcode.kind == LABEL:
    return "$1:" % opcode.label
  var name = ""
  if opcode.kind == MOV:
    if opcode.mov == MOVLEA:
      name = "LEA"
    else:
      name = $opcode.mov
  else:
    name = $opcode.kind
  result = repeat("    ", 1) & leftAlign(toUpperAscii(name), 7, ' ')
  var arg = case opcode.kind:
  of MOV, SUBQ, LEA:
    "$1$2" % [leftAlign("$1," % toBinary(opcode.source), 20, ' '), toBinary(opcode.destination)]
  of INT:
    $opcode.arg
  of PUSHQ, POPQ, DIVL:
    toBinary(opcode.value)
  of CALL:
    opcode.label
  of JMP, JNE:
    opcode.label
  of CMP, ADD:
    "$1$2" % [leftAlign("$1," % toBinary(opcode.left), 20, ' '), toBinary(opcode.right)]
  else:
    ""
  result.add(arg)
