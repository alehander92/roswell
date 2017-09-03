# roswell

A programming language playground

## what is it

Currently, a compiler of a very basic python-like statically typed language with numbers, strings, booleans and arrays to x86_64 assembly and C

## state

Currently that's the result of mostly playing in my vacation week

So very basic stuff is implemented: simple type checking and an assembler and C backend. 
Functions which work with mostly int-s and if-s and stdout kinda work.

That's my first real experience with assembler, so I have a lot to optimize/fix.

```ruby
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

## architecture

I like the nanopass approach, but I am not extreme with it.
Currently the compiler is basically a pipeline going through several passes.

There are 7 passes currently:

* Parser

    source -> syntax tree
* Type checker
  	
  	syntax tree -> syntax tree with type info
* Converter to three address code
  	
  	syntax tree with type info -> a list of functions with list of triplets of three address nodes
* Machine independent optimizer
  	
  	three address code -> three address code with optimizations
* Target emitter
  	
  	three address code with optimizations -> for assembler, a node object with opcode objects, for c, the raw code
* Machine dependent optimizer
  	
  	opcode objects -> opcode objects with optimizations, for assembler assembler-specific optimizations
* Binary
  	
  	opcode objects with optimizations -> binary, for assembler, renders the opcodes in at\&t syntax and assembles/links with as, ld



## motivation

I've experimented with implementing various simple languages/features in other projects,
but I still haven't played a lot with optimizers, garbage collectors and lower level code generation.
Coincidentally I find myself with a compiler related book and a stack of similar papers/projects I've wanted to take a look at, so I'll use this ~language~ as a temporary learning ground

That's not my "dream language", I still want to go deeper in a lot of topics before coming up with 
some kind of "unique" language design/philosophy (and that would take years).
On the other hand I am not just reimplementing an existing language because I want to have the flexibility to adapt it to my needs/interest (and because I don't want to uh reimplement the whole C standard in my free time)
