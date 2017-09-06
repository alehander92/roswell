import ../triplet, ../ast, ../top, math
import strutils, sequtils

# machine-independent optimizer
proc arrayOptimize*(module: var TripletModule) =
  # minimze variables
  for function in module.functions.mitems:
    var triplets: seq[Triplet] = @[]
    var z = 0
    var node: TripletAtom 
    for triplet in function.triplets.mitems:
      if triplet.kind == TArray and isMachine(triplet.destination.label):
        var next = function.triplets[z + triplet.arrayCount + 1]
        if next.kind == TSave:
          node = next.destination
          triplet.destination = node
      elif triplet.kind == TIndexSave and node != nil:
        triplet.sIndexable = node
      elif triplet.kind == TSave and node != nil:
        node = nil
        continue
      triplets.add(triplet)
    function.triplets = triplets
