import strutils

proc leftAlign*(a: string, count: Natural, padding: char): string =
  result = a
  let b: int = len(a)
  if b < count:
    result.add(padding.repeat(count - b))

