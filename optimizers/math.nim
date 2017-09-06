import ../triplet, ../ast, ../top
import strutils, sequtils

proc isMachine*(label: string): bool
proc constOp(op: Operator, left: Node, right: Node): Node
proc replace(next: var Triplet, label: string, constant: TripletAtom)

# machine-independent optimizer
proc mathOptimize*(module: var TripletModule) =
  # merge operations
  for function in module.functions.mitems:
    var triplets: seq[Triplet] = @[]
    var z = 0
    for triplet in function.triplets.mitems:
      if triplet.kind == TBinary and triplet.left.kind == UConstant and triplet.right.kind == UConstant and
         triplet.left.node.kind == AInt and triplet.right.node.kind == AInt:
        var constant = TripletAtom(kind: UConstant, node: constOp(triplet.op, triplet.left.node, triplet.right.node), typ: intType)
        assert triplet.destination.kind == ULabel
        if not isMachine(triplet.destination.label):
          triplets.add(Triplet(kind: TSave, destination: triplet.destination, value: constant))
        else:
          if z < len(function.triplets) - 1:
            var next = function.triplets[z + 1]
            replace(next, triplet.destination.label, constant)
      else:
        triplets.add(triplet)
      inc z
    function.triplets = triplets

proc isMachine*(label: string): bool =
  result = len(label) > 0 and label[0] == 't' and label[1..^1].isDigit()

proc constOp(op: Operator, left: Node, right: Node): Node =
  if left.kind != right.kind:
    return left
  case left.kind:
  of AInt:
    case op:
      of OpAdd: return Node(kind: AInt, value: left.value + right.value)
      of OpSub: return Node(kind: AInt, value: left.value - right.value)
      of OpMul: return Node(kind: AInt, value: left.value * right.value)
      of OpDiv: return Node(kind: AInt, value: left.value div right.value)
      else:     return left
  else:
    return left

proc sameLabel(t: TripletAtom, label: string): bool =
  return t.kind == ULabel and t.label == label

template update(l: untyped): untyped =
  if sameLabel(next.`l`, label):
    next.`l` = constant
    updated = true

proc replace(next: var Triplet, label: string, constant: TripletAtom) =
  var updated = false
  case next.kind:
  of TBinary:
    update(left)
    if not updated:
      update(right)
  of TUnary:
    update(u)
  of TSave:
    update(value)
  of TIf:
    update(conditionLabel)
  of TArg:
    update(source)
  of TIndex:
    update(iindex)
  of TIndexSave:
    update(sIndex)
    if not updated:
      update(sValue)
  else: discard
