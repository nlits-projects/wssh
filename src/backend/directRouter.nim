import jester, ws, ws/jester_extra, asyncshell, packets, utils

import std/[osproc, macros, logging]



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

    # init, convey that the command has started for commands with no text output
    let initPacket = ctxCheck(newByteUpdatePacket, "", false)
    await ws.sendActionPacket(initPacket)

    # handle
    let exitCode = await currentProcess.asyncHandleProcess(stdoutHandle, stderrHandle)
    let packet = ctxCheck(newFinishPacket, exitCode)
    await ws.sendActionPacket(packet)
    # Cleanup
    currentProcess = nil




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
    logging.debug($packet) # debug

    # Main packet handle

    case packet.kind # Packets server accepts: Close, Run, Input
    of pkRun:
      if packet.processID != -1:
        logging.warn("ClientError: Inccorrect client packet structure. [-> Server]")
        ws.close() # Error out
        break
      if currentProcess != nil:
        logging.warn("ClientError: Process in progress. [-> Server]")
        ws.close() # Error out
        break
       
      let command = packet.command
      currentCommand = command

      # Presend before we lose track of the callback
      let confirmationPacket = ctxCheck(newConfirmActionPacket, packet.kind)
      await ws.send(confirmationPacket.renderBin, Opcode.Binary)

      # Start process. Args is unused because of poEvalCommand
      {.gcsafe.}: # Safe. When threads are enabled it is a gcsafe threadvar.
        let workingDir = wsshConf.shellWorkingDir
      currentProcess = startProcess(command, options={poUsePath, poEvalCommand, poInteractive}, workingDir=workingDir) 

      asyncCheck directRunCallback()() # Handle the process and exit of that process


      continue # Skip confirmation

    of pkClose:
      if currentProcess.isNil: # No current process
        logging.warn("ClientError: No process to close. [-> Server]")
        ws.close() # Error to client
        break
      currentProcess.terminate() # Ctrl-c sends terminate

    of pkInput:
      if packet.processID != -1:
        logging.warn("ClientError: Inccorrect client packet structure. [-> Server]")
        ws.close() # Error out. Only the server should be sending process, command, etc.
        break
      if currentProcess.isNil: # No current process
        logging.warn("ClientError: No process to input to. [-> Server]")
        ws.close() # Error to client
        break

      await currentProcess.asyncWriteIn(packet.input) # write input to stdin
      

    of pkConfirmAction:
      # Confirm action should only be sent to confirm an action.
      logging.warn("ClientError: Unchecked confirm packet [-> Server]")
      ws.close() # Error codes and message have not yet been added to ws, I will add them later.
      break

    else:
      # These packets were not meant to be sent to the server
      logging.warn("ClientError: Improper packet kind " & $packet.kind & " [-> Server]")
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

    # Handle connection
    await directWsHandle(ws)

    # Handle complaints
    respErr Http400, "Bad packet sent."

  
  # Handle errors
  error WebSocketClosedError:
    let message = "Websocket Closed: " & exception.msg & " [Non-Resumable]"
    logging.error(message)
    respErr Http410, message # Connection GONE

  error WebSocketProtocolMismatchError:
    let message = "Socket tried to use an unknown protocol: " & exception.msg
    logging.error(message)
    respErr Http400, message # Upgrade to http

  error WebSocketHandshakeError:
    let message = "Socket handshake failed: " & exception.msg
    logging.error(message)
    respErr Http400, message

  error WebSocketPacketTypeError:
    let message = "WSSH pakcet type error: " & exception.msg
    logging.error(message)
    respErr Http400, message

  error WebSocketError:
    let message = $exception.name & ": " & exception.msg
    logging.error(message)
    respErr Http500, message

  error Http404:
    respErr Http404, "Couldn't find webpage."

  error Http500:
    respErr Http500, "A internal server error occured."
      

export direct
