import jester, ws, ws/jester_extra, asyncshell, packets, utils

proc directWsHandle(ws: WebSocket) {.async.} =
  discard
  
router directRouter:
  get "/hello":
    resp "<h1>Hello World!</h1>"

  get "/ws":
    var ws = await newWebSocket(request)
    await ws.send(newInitPacket(WsshMode.Direct).renderBin)
    await directWsHandle(ws)


export directRouter