import jester, cligen
import routers, utils


proc wssh(mode=WsshMode.Direct, jport=80, jbindAddr="localhost", jreusePort=false, jnumThreads=0) =
  let port = Port(jport)
  let settings = newSettings(port=port, # appName="wssh", # Apparently appName is deprecated in the http spec
    bindAddr=jbindAddr, reusePort=jreusePort, staticDir=getStaticPath()) #, numThreads=jnumThreads)

  var jester: Jester

  case mode
  of Direct:
    jester = initJester(directRouter, settings=settings)
  of MultiProxy:
    discard

  jester.serve()



when isMainModule:
  import cligen
  dispatch wssh, help={
    "mode": "Options: Direct, MultiProxy. Look at README.md for more details.",
    "jport": "Which port the jester web server should use.",
    "jbindAddr": "Which address(es) should be used by the jester web server.",
    "jreusePort": "Whether jester should reuse http ports. If you don't know what this does don't touch it.",
    "jnumThreads": "In development. (In the latest commit of jester but not the release)"
  }, short={
    "jport": 'p',
    "jbindAddr": 'b',
    "jreusePort": '\0',
    "jnumThreads": '\0'
  }