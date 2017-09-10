import type_env, types, core
import tables

var TOP_ENV* = type_env.newEnv(nil)

var intType* =                      simpleType("Int")
var stringType* =                   simpleType("String")
var boolType* =                     simpleType("Bool")
var voidType* =                     simpleType("Void")
var charType* =                     simpleType("Char")
var floatType* =                    simpleType("Float")
var nilType* =                      simpleType("Nil")
var errorType* =                    simpleType("Error")
var defaultType* =                  Type(kind: Default)

var mathIntInt* =                   functionType(@[intType, intType, intType])
var logicBoolBool* =                functionType(@[boolType, boolType, boolType])
var compareIntIntBool* =            functionType(@[intType, intType, boolType])

# later in lib
var mapType* =                      functionType(
  @[complexType("Array", simpleType("T")),
    functionType(@[simpleType("T"), simpleType("U")]),
    complexType("Array", simpleType("U"))],
  @["T", "U"])

TOP_ENV.define("display",           functionType(@[defaultType, voidType]), predefined=core.PDisplayDefinition)
TOP_ENV.define("text",              functionType(@[stringType, stringType]), predefined=core.PTextDefinition)
TOP_ENV.define("text",              functionType(@[intType, stringType]), predefined=core.PTextIntDefinition)
TOP_ENV.define("text",              functionType(@[defaultType, stringType]), predefined=core.PTextDefaultDefinition)
TOP_ENV.define("exit",              functionType(@[intType, voidType]), predefined=core.PExitDefinition)
TOP_ENV.define("map",               mapType)

TOP_ENV.define("+",                 mathIntInt)
TOP_ENV.define("-",                 mathIntInt)
TOP_ENV.define("*",                 mathIntInt)
TOP_ENV.define("/",                 mathIntInt)
TOP_ENV.define("and",               logicBoolBool)
TOP_ENV.define("or",                logicBoolBool)
TOP_ENV.define("==",                compareIntIntBool)
TOP_ENV.define("%",                 mathIntInt)

TOP_ENV.define("RuntimeError",      errorType)
TOP_ENV.define("ExitError",         errorType)