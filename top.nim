import env, types, core
import tables

var TOP_ENV* = newEnv(nil)

var intType* =                      Type(kind: Simple, label: "Int")
var stringType* =                   Type(kind: Simple, label: "String")
var boolType* =                     Type(kind: Simple, label: "Bool")
var voidType* =                     Type(kind: Simple, label: "Void")

var mathIntInt* =                   functionType(@[intType, intType, intType])
var logicBoolBool* =                functionType(@[boolType, boolType, boolType])
var compareIntIntBool* =            functionType(@[intType, intType, boolType])

TOP_ENV.define("display",           functionType(@[stringType, voidType]), predefined=core.displayDefinition)
TOP_ENV.define("display",           functionType(@[intType, voidType]), predefined=core.displayIntDefinition)
TOP_ENV.define("exit",              functionType(@[intType, voidType]), predefined=core.exitDefinition)

TOP_ENV.define("+",                 mathIntInt)
TOP_ENV.define("-",                 mathIntInt)
TOP_ENV.define("*",                 mathIntInt)
TOP_ENV.define("/",                 mathIntInt)
TOP_ENV.define("and",               logicBoolBool)
TOP_ENV.define("or",                logicBoolBool)
TOP_ENV.define("==",                compareIntIntBool)
TOP_ENV.define("%",                 mathIntInt)


