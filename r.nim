type
  A* = ref object of RootObj
    a*: int

  B* = ref object of A
    b*: int

proc run =
  var a = A(a: 2)
  var b = B(a: 2)
  var l = @[2]


run()
