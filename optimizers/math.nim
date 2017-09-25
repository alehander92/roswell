import ../triplet, ../ast, ../top, ../operator
import strutils, sequtils

proc isMachine*(label: string): bool
proc constOp(op: Operator, left: TripletAtom, right: TripletAtom): TripletAtom
proc replace(next: var Triplet, label: string, constant: TripletAtom)

# machine-independent optimizer
proc mathOptimize*(module: var TripletModule) =
  # merge operations
  for function in module.functions.mitems:
    var triplets: seq[Triplet] = @[]
    var z = 0
    for triplet in function.triplets.mitems:
      if triplet.kind == TBinary and triplet.left.kind == UInt and triplet.right.kind == UInt:
        var constant = constOp(triplet.op, triplet.left, triplet.right)
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

proc constOp(op: Operator, left: TripletAtom, right: TripletAtom): TripletAtom =
  if left.kind != right.kind:
    return left
  case left.kind:
  of UInt:
    case op:
      of OpAdd:   return TripletAtom(kind: UInt,  i: left.i + right.i, typ: intType)
      of OpSub:   return TripletAtom(kind: UInt,  i: left.i - right.i, typ: intType)
      of OpMul:   return TripletAtom(kind: UInt,  i: left.i * right.i, typ: intType)
      of OpDiv:   return TripletAtom(kind: UInt,  i: left.i div right.i, typ: intType)
      of OpEq:    return TripletAtom(kind: UBool, b: left.i == right.i, typ: boolType)
      of OpNotEq: return TripletAtom(kind: UBool, b: left.i != right.i, typ: boolType) 
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
