# roswell

A programming language playground

I've experimented with many implementing various simple languages/features in other projects,
but I still haven't played a lot with optimizers, garbage collectors and lower level code generation.
Coincidentally I find myself with a compiler related book and a stack of similar papers/projects I've wanted to take a look at, so I'll use this ~language~ as a temporary learning ground

That's not my "dream language", I still want to go deeper in a lot of topics before coming up with 
some kind of "unique" language design/philosophy (and that would take years).
On the other hand I am not just reimplementing an existing language because I want to have the flexibillity to adapt it to my needs/interest (and because I don't want to reimplement the whole C standard in my free time)

# state

Currently that's the result of playing in my vacation week

So very basic stuff is implemented: simple type checking and an assembler backend. 
Functions which work with mostly int-s and if-s and stdout kinda work.
That's my first real experience with assembler, so I have a lot to optimize/fix.

```python
Int -> Int
def name(a):
  if ==(%(a 2) 0):
    display('even')
    return 0
  else:
    display('odd')
    return 1

def main:
  var a = name(2)
```
