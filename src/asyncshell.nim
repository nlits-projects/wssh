import std/[osproc, asyncdispatch, streams]


type CallbackProc* = proc (s: string): Future[void] {.closure.}

#[]

proc asyncWaitProcess*(p: Process, delay=10): Future[int] {.async.} =
  while p.peekExitCode() == -1:
    await sleepAsync(10)
  return p.peekExitCode()

]#

proc asyncHandleProcess*(p: Process, 
  stdoutHandle, stderrHandle: CallbackProc, delay=10): Future[int] {.async.} =
    ## Waits until process p finishes while sending any new data in stdout or stderr to it's respective handles.
    ## Checks for updates every delay (ms). To register a new one every cycle set delay to 1

    let sout = p.peekableOutputStream
    let serr = p.peekableErrorStream

    while p.peekExitCode() == -1:
      if not sout.atEnd: # If more data is written, send all new data
        await stdoutHandle(sout.readAll)
      if not serr.atEnd:
        await stderrHandle(serr.readAll)

      await sleepAsync(10)

    if not sout.atEnd: # If more data is written, send all new data, then finish
      await stdoutHandle(sout.readAll)
    if not serr.atEnd:
      await stderrHandle(serr.readAll)

    return p.peekExitCode()
  