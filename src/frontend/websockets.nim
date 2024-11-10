import std/[jsffi, asyncjs]
import utils
from std/dom import Event

# ==============================================================================================================================
# Native Websocket Impl
# ==============================================================================================================================
# Follows https://developer.mozilla.org/en-US/docs/Web/API/WebSocket with some conversion between nim strings and ArrayBuffers
# ==============================================================================================================================



type WebSocketReadState* {.pure.} = enum
  CONNECTING = 0
  OPEN = 1
  CLOSING = 2
  CLOSED = 3


type # events
  CloseEvent* = ref object of Event
    code*: int
    reason*: cstring
    wasClean*: bool

  MessageEvent* = ref object of Event
    data*: ArrayBuffer
    origin*: cstring

  EventHandle*[T] = proc (e: T) {.closure.}

type WebSocket* {.importc.} = ref object of JsObject
  binaryType*: cstring
  bufferedAmount*: int
  extensions*: cstring
  protocol*: cstring
  readyState*: WebSocketReadState
  url*: cstring
  onclose*: EventHandle[CloseEvent]
  onerror*: EventHandle[Event] # Generic
  onmessage*: EventHandle[MessageEvent]
  onopen*: EventHandle[Event] # Generic



proc newWebSocket*(url: cstring, protocols: seq[cstring]): WebSocket {.importjs: "new WebSocket(@)".}

proc newWebSocket*(url: cstring, protocols: cstring): WebSocket {.importjs: "new WebSocket(@)".}

proc newWebSocket*(url: cstring): WebSocket {.importjs: "new WebSocket(@)".}

proc close*(ws: WebSocket, code: int, reason: cstring) {.importjs: "(#.close(@))".}

proc close*(ws: WebSocket) {.importjs: "(#.close())".}

proc send*(ws: WebSocket, data: JsObject) {.importjs: "#.send(#)"}

proc addEventListener*(ws: WebSocket, name: string, f: EventHandle[Event]) {.importjs: "#.addEventListener(#, #)".}

proc addEventListener*(ws: WebSocket, name: string, f: EventHandle[Event], options: JsObject) {.importjs: "#.addEventListener(#, #, #)".}


# ==============================================================================================================================
# Async Custom Websocket Impl
# ==============================================================================================================================



type AsyncWebSocket* = ref object
  ws*: WebSocket
  cache: seq[string]
  pcache: seq[proc (s: string)]
  ppcache: seq[proc (s: string)] # Prority Pcache. QUICKPATCH: Bug in timing of confirmAction packets being recieved

proc waitForEvent*(ws: AsyncWebSocket, eventName: cstring): Future[Event] {.async.}

proc waitForEvent*(ws: AsyncWebSocket, eventName: cstring): Future[Event] =
  ## Wait for event of ws to happen before resolving.
  proc handle(resolve: proc (response: Event)) =
    ws.ws.addEventListener(eventName, resolve, js{"once": true, "passive": true})
  
  result = newPromise[Event](handle)


proc newAsyncWebsocket*(url: string): Future[AsyncWebSocket] {.async.} =
  ## Create and open a new async websocket. Handles incoming messages.

  var res = AsyncWebSocket(ws: newWebSocket(url))

  proc inner() {.async.} =
    while res.ws.readyState == WebSocketReadState.OPEN:
      let e = await res.waitForEvent("message") # Get message in one unified stream
      let msge = MessageEvent(e)
      let data = arrBufferToNimStr(msge.data)

      if res.pcache.len == 0 and res.ppcache.len == 0:
        res.cache.insert(data, 0) # Add to cache if no cached promises
      elif res.ppcache.len > 0:
        let promiseComplete = res.ppcache.pop()
        promiseComplete(data) # Complete promise
      else:
        let promiseComplete = res.pcache.pop()
        promiseComplete(data) # Complete promise
    
  discard await res.waitForEvent("open") # wait for socket to open
  discard inner() # Message handle
  return res
  

proc send*(ws: var AsyncWebSocket, data: string) {.async.} =
  ## Send with conversion between nim string and arrayBuffer
  let data = nimStrToArrBuffer(data)
  ws.ws.send(data)


proc recvFromPCache(ws: var AsyncWebSocket, priority: bool): Future[string] =
  ## Recv by adding promise complete function to the pcache. Called when cache has no messages

  proc handle(resolve: proc (s: string)) =
    # echo "Cached into pcache"
    if priority:
      ws.ppcache.insert(resolve, 0)
    else:
      ws.pcache.insert(resolve, 0)

  result = newPromise[string](handle)



proc recv*(ws: var AsyncWebSocket, priority=false): Future[string] {.async.} =
  ## Recv the next non-error/close/open message and convert it to nim string.

  if ws.cache.len == 0:
    result = await ws.recvFromPCache(priority)
  else:
    result = ws.cache.pop()


