import macros

proc a(x: int): int =
  return 2

template buildMacro(b: varargs[untyped]): untyped =
  echo treerepr(b)
  # var buildResult: seq[nnkNode] = @[]
  # var results: seq[seq[nnkNode]] = @[]
  # `b`

# template call(b: varargs[untyped]): untyped =
#   results.add(@[])
#   `b`
#   buildResult.add(nnkCall.newTree(*results[^1]))
#   discard results.pop()

# # macro call(b: varargs[untyped]): untyped =
# #   echo treerepr(b)
# #   result = nnkCall.newTree(
# #     newIdentNode(!"a"),
# #     b[0])
#   # nnkCall.newTree(`b`)

# template ident(b: untyped): untyped =

#   newIdentNode(!`b`)

var call = 2

macro c(b: untyped): untyped =
  result = buildMacro:
    call:
      ident("b")
      ident(2)


c(4)
