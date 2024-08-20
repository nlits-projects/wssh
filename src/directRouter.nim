import jester, ws, ws/jester_extra, asyncshell, packets, utils

import std/[osproc, macros]



#[
----------------------------------------------------
Utils
----------------------------------------------------
]#


macro ctxCheck(call: untyped, args: varargs[untyped]): untyped =

  let call1 = newNimNode(nnkCall)
  var call2 = newNimNode(nnkCall)
  # Fix structural issues
  call1.add call
  call2.add call
  for arg in args:
    call1.add arg
    call2.add arg


  call2.add newDotExpr(newIdentNode("currentProcess"), newIdentNode("processID"))
  call2.add newIdentNode("currentCommand")

  result = quote do:
    block:
      if currentProcess.isNil:
        `call1`
      else:
        `call2`

  # echo result.repr
  # echo result.treeRepr



      

proc recvPacket(ws: WebSocket): Future[Packet] {.async.} =
  ## Receive a binary packet and convert it to a nim object
  let strPacket = cast[string](await ws.receiveBinaryPacket())
  return strPacket.fromBin

proc sendActionPacket(ws: WebSocket, p: Packet) {.async.} =
  ## A utility to send a packet and assert completion 
  let bin = p.renderBin
  await ws.send(bin, Opcode.Binary)

  let confirmation = await ws.recvPacket()
  doAssert confirmation.kind == pkConfirmAction # Confirm packet kind
  doAssert confirmation.action == p.kind # Confirm confirmation kind






#[
----------------------------------------------------
Callbacks
----------------------------------------------------
]#

template stdoutCallback(isErr: bool = false): untyped =
  proc (bytes: string) {.async, gcsafe.} = # 
    let packet = ctxCheck(newByteUpdatePacket, bytes, bool(isErr))
    await ws.sendActionPacket(packet)


template directRunCallback(): untyped =
  proc () {.async, gcsafe.} = # Handle the process end
    let stdoutHandle = stdoutCallback()
    let stderrHandle = stdoutCallback(true)

    let exitCode = await currentProcess.asyncHandleProcess(stdoutHandle, stderrHandle)
    let packet = ctxCheck(newFinishPacket, exitCode)
    await ws.sendActionPacket(packet)




#[
----------------------------------------------------
Direct Router
----------------------------------------------------
]#


  

proc directWsHandle(ws: WebSocket) {.async.} =
  ## Websocket direct handle. The main function of the direct router

  var currentCommand: string # Current command linked to current process
  var currentProcess: Process # Wssh can only handle one command at a time as of now. Subprocess should still work

  while ws.readyState == Open:
    let packet = await ws.recvPacket()


    # Main packet handle

    case packet.kind # Packets server accepts: Close, Run, Input
    of pkRun:
      if packet.processID != -1:
        ws.close() # Error out
        break
      let command = packet.command
      currentCommand = command

      currentProcess = startProcess(command, options={poUsePath, poEvalCommand, poInteractive}) # Start process. Args is unused because of poEvalCommand

      asyncCheck directRunCallback()() # Run the command

    of pkClose:
      if currentProcess.isNil: # No current process
        ws.close() # Error to client
        break
      currentProcess.terminate() # Ctrl-c sends terminate

    of pkInput:
      if packet.processID != -1:
        ws.close() # Error out. Only the server should be sending process, command, etc.
        break
      if currentProcess.isNil: # No current process
        ws.close() # Error to client
        break

      await currentProcess.asyncWriteIn(packet.input) # write input to stdin
      

    of pkConfirmAction:
      # Confirm action should only be sent to confirm an action.
      ws.close() # Error codes and message have not yet been added to ws, I will add them later.
      break

    else:
      # These packets were not meant to be sent to the server
      ws.close() # Error
      break

    # Complete it
    let confirmationPacket = ctxCheck(newConfirmActionPacket, packet.kind)
    await ws.send(confirmationPacket.renderBin, Opcode.Binary)





router direct:
  get "/hello":
    resp "<h1>Hello World!</h1>"

  get "/ws":
    var ws = await newWebSocket(request)
    await ws.sendActionPacket(newInitPacket(WsshMode.Direct))
    await directWsHandle(ws)


export direct