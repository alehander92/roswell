import type_env, types, core, ast
import tables

var TOP_ENV* = type_env.newEnv[Node](nil)

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
var mathIntBool* =                  functionType(@[intType, intType, boolType])
var logicBoolBool* =                functionType(@[boolType, boolType, boolType])
var logicBool* =                    functionType(@[boolType, boolType])
var compareIntIntBool* =            functionType(@[intType, intType, boolType])
var optionEnumType* =               enumType("OptionEnumType", @["~Ok", "~None"])


# later in lib
# var mapType* =                      functionType(
#   @[complexType("Sequence", simpleType("T")),
#     functionType(@[simpleType("T"), simpleType("U")]),
#     complexType("Sequence", simpleType("U"))],
#   @["T", "U"])

TOP_ENV.define("display",           functionType(@[defaultType, voidType]), predefined=core.PDisplayDefinition)
TOP_ENV.define("text",              functionType(@[stringType, stringType]), predefined=core.PTextDefinition)
TOP_ENV.define("text",              functionType(@[intType, stringType]), predefined=core.PTextIntDefinition)
TOP_ENV.define("text",              functionType(@[defaultType, stringType]), predefined=core.PTextDefaultDefinition)
TOP_ENV.define("exit",              functionType(@[intType, voidType]), predefined=core.PExitDefinition)
# TOP_ENV.define("map",               mapType)

TOP_ENV.define("+",                 mathIntInt)
TOP_ENV.define("-",                 mathIntInt)
TOP_ENV.define("*",                 mathIntInt)
TOP_ENV.define("/",                 mathIntInt)
TOP_ENV.define("and",               logicBoolBool)
TOP_ENV.define("or",                logicBoolBool)
TOP_ENV.define("not",               logicBool)
TOP_ENV.define("==",                compareIntIntBool)
TOP_ENV.define("!=",                compareIntIntBool)
TOP_ENV.define("%",                 mathIntInt)
TOP_ENV.define(">",                 mathIntBool)
TOP_ENV.define(">=",                mathIntBool)
TOP_ENV.define("<",                 mathIntBool)
TOP_ENV.define("<=",                mathIntBool)


TOP_ENV["RuntimeError"] =           errorType
TOP_ENV["ExitError"] =              errorType
TOP_ENV["Option"] =                 Type(kind: Generic, label: "Option", genericArgs: @["T"], complex: dataType("Option", optionEnumType, -1, @[@[simpleType("T")], @[]]), instantiations: @[])

var kindType* = Type(kind: Enum, label: "NodeEnum", variants: @[
      "~AProgram", "~AGroup", "~ARecord", "~AEnum", "~AData", "~AField", "~AInstance", "~AIField", "~ADataInstance", "~ABranch",
       "~AInt", "~AEnumValue", "~AFloat", "~ABool", "~ACall", "~AFunction", "~ALabel",
       "~AString", "~APragma", "~AChar", "~AArray", "~AList", "~AOperator", "~AType",
       "~AReturn", "~AIf", "~AForEach", "~AAssignment", "~ADefinition", "~AMember",
       "~AIndex", "~AIndexAssignment", "~APointer", "~ADeref", "~ADataIndex", "~AImport",
       "~AMacro", "~AMacroInvocation"])
proc listType*(elementType: Type): Type
var operatorType* = Type(kind: Enum, label: "Operator", variants: @["~OpAnd", "~OpOr", "~OpEq", "~OpMod", "~OpAdd", "~OpSub", "~OpMul", "~OpDiv", "~OpNotEq", "~OpGt", "~OpGte", "~OpLt", "~OpLte", "~OpXor", "~OpNot", "~OpAt"])
var nodeType* = Type(kind: Data, label: "Node", dataKind: kindType, active: -1, branches: @[])
nodeType.branches = @[
    @[stringType, listType(nodeType), listType(nodeType)],
    @[],
    @[],
    @[stringType, listType(stringType)],
    @[stringType, listType(nodeType)],
    @[stringType],
    @[stringType, nodeType],
    @[stringType, listType(nodeType)],
    @[stringType, listType(nodeType)],
    @[stringType],
    @[intType],
    @[stringType, intType],
    @[floatType],
    @[boolType],
    @[nodeType, listType(nodeType)],
    @[stringType, listType(stringType), nodeType],
    @[stringType],
    @[],
    @[],
    @[charType],
    @[listType(nodeType)],
    @[listType(nodeType)],
    @[operatorType],
    @[],
    @[nodeType],
    @[nodeType, nodeType],
    @[stringType, stringType, nodeType, nodeType],
    @[stringType, nodeType, boolType],
    @[stringType, nodeType],
    @[nodeType, stringType],
    @[],
    @[],
    @[],
    @[],
    @[],
    @[],
    @[],
    @[]
  ]

proc optionType*(typ: Type): Type =
  return complexType("Option", @[typ])

proc arrayType*(elementType: Type, count: int): Type =
  return complexType("Array", @[elementType, simpleType($count)])

proc listType*(elementType: Type): Type =
  return complexType("List", @[elementType])

