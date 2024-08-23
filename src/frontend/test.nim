import ../backend/packets, websockets
import std/[dom, asyncjs]


## THIS FILE IS MEANT FOR TESTING AND DEMO PURPOSES AND IS NOT A RELEASE VERSION

  

when not defined(js):
  {.error: "Please compile this frontend nim code with nim js".}


# Utils
proc toCString(i: int): cstring {.importjs: "#.toString()".}

proc `&`(a, b: cstring): cstring {.importjs: "(# + #)".}

proc confirmedSend(ws: var AsyncWebSocket, p: Packet) {.async.} =
  echo "Sending ", p

  await ws.send(renderBin(p))
  let bin = await ws.recv(true)
  let packet = fromBin(bin)
  if packet.kind != pkConfirmAction:
    raise ValueError.newException("Got " & $packet.kind & ", expected confirmation packet.")
  if packet.action != p.kind:
    raise ValueError.newException("Confirmation Error: Got " & $packet.action & ", expected " & $p.kind)



# Types
type State = ref object
  stdout: string
  stderr: string
  textOutput: string
  ws: AsyncWebSocket
  currentProcess: int


# Relevant elements
let output = document.getElementById("output")
let input = document.getElementById("input")
let inputButton = document.getElementById("input-button")
let errorBox = document.getElementById("error")
let status = document.getElementById("status")
let killButton = document.getElementById("kill")

# Setup
var s = State()

# Main functions

proc handlePacket(p: Packet) {.async.} =
  echo $p # debug

  case p.kind
  of pkInit:
    s.textOutput &= "Init\n"
  of pkFinish:
    s.textOutput &= "Exit with code " & $p.code & "\n"
  of pkByteUpdate:
    if p.isErr:
      s.stderr &= p.bytes
    else:
      s.stdout &= p.bytes
    s.textOutput &= p.bytes
  of pkConfirmAction: 
    raise ValueError.newException("Unhandled confirm packet: " & $p.action)
  else:
    discard

  output.textContent = cstring(s.textOutput)


proc main() {.async.} =
  # WS
  s.ws = await newAsyncWebSocket("/ws")
  s.ws.ws.binaryType = "arraybuffer"
  echo s.ws.ws.url

  # WS events
  s.ws.ws.onerror = proc (e: Event) =
    echo "Websocket encountered an unspecified error"
    errorBox.textContent &= cstring"Websocket encountered an unspecified error" & "\r\n"

  s.ws.ws.onclose = proc (e: CloseEvent) =
    echo "Websocket closed with: ", e.code, " ", e.reason, " ", e.wasClean
    errorBox.textContent &= cstring"Websocket closed with code " & e.code.toCString & " and message: " & e.reason & "\r\n"



  # Main loop
  while s.ws.ws.readyState == WebSocketReadState.OPEN:
    let packetBin = await s.ws.recv()
    let packet = fromBin(packetBin)

    await handlePacket(packet)

    let confirmation = newConfirmActionPacket(packet.kind)
    await s.ws.send(renderBin(confirmation))

    s.currentProcess = packet.processID # Track current process
    status.textContent = cstring(packet.command & " " & $packet.processID)


# Start main

discard main()


# DOM event handles

inputButton.onclick = proc (e: Event) =
  var packet: Packet
  if s.currentProcess != -1: # If current process is running
    packet = newInputPacket($input.value)
  else:
    packet = newRunPacket($input.value)

  discard s.ws.confirmedSend(packet)
  input.value = cstring""

killButton.onclick = proc (e: Event) =
  let packet = Packet(kind: pkClose)
  discard s.ws.confirmedSend(packet)