import type_env, types, core
import tables

var TOP_ENV* = type_env.newEnv(nil)

var intType* =                      Type(kind: Simple, label: "Int")
var stringType* =                   Type(kind: Simple, label: "String")
var boolType* =                     Type(kind: Simple, label: "Bool")
var voidType* =                     Type(kind: Simple, label: "Void")
var charType* =                     Type(kind: Simple, label: "Char")
var floatType* =                    Type(kind: Simple, label: "Float")
var nilType* =                      Type(kind: Simple, label: "Nil")
var errorType* =                    Type(kind: Simple, label: "Error")

var mathIntInt* =                   functionType(@[intType, intType, intType])
var logicBoolBool* =                functionType(@[boolType, boolType, boolType])
var compareIntIntBool* =            functionType(@[intType, intType, boolType])

TOP_ENV.define("display",           functionType(@[stringType, voidType]), predefined=core.PDisplayDefinition)
TOP_ENV.define("display",           functionType(@[intType, voidType]), predefined=core.PDisplayIntDefinition)
TOP_ENV.define("exit",              functionType(@[intType, voidType]), predefined=core.PExitDefinition)

TOP_ENV.define("+",                 mathIntInt)
TOP_ENV.define("-",                 mathIntInt)
TOP_ENV.define("*",                 mathIntInt)
TOP_ENV.define("/",                 mathIntInt)
TOP_ENV.define("and",               logicBoolBool)
TOP_ENV.define("or",                logicBoolBool)
TOP_ENV.define("==",                compareIntIntBool)
TOP_ENV.define("%",                 mathIntInt)

TOP_ENV.define("RuntimeError",      errorType)

