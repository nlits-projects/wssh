import std/jsffi

type ArrayBuffer* {.importc.} = ref object of JsObject
  byteLength*: int
  detached*: bool
  maxByteLength*: int
  resizable*: bool

type UInt8Array* {.importc.} = ref object of JsObject

proc newArrayBuffer*(length: int): ArrayBuffer {.importjs: "new ArrayBuffer(#)".}

proc newArrayBuffer*(length: int, maxLength: int): ArrayBuffer {.importjs: "new ArrayBuffer(#, {maxByteLength: #})".}

proc newUInt8Array*(buf: ArrayBuffer): UInt8Array {.importjs: "new Uint8Array(#)".}
  ## Adds a uint8 array layer to arraybuffer to modify and read it

proc `[]`*(ui8: UInt8Array, index: int): uint8 {.importjs: "#[#]".}

proc `[]=`*(ui8: UInt8Array, index: int, value: uint8) {.importjs: "#[#] = #".}

  
proc nimStrToArrBuffer*(s: string): ArrayBuffer =
  ## Convert a nim string to a js array buffer
  let length = s.len
  result = newArrayBuffer(length)

  var modif = newUInt8Array(result) # Access to edit

  for i in 0..s.high:
    modif[i] = uint8(s[i])

proc arrBufferToNimStr*(a: ArrayBuffer): string =
  ## Convert js array buffer to nim string
  result = newString(a.byteLength)
  var reader = newUInt8Array(a)

  for i in 0..result.high:
    result[i] = char(reader[i])