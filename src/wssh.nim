import jester
import directRouter, utils
import std/logging



proc main() =
  let conf = wsshConf # load conf


  # Init Logging
  var logger: Logger
  const fmtStr = "[$levelname] ($datetime) $appdir/$appname: "

  if conf.loggingFile == "":
    logger = newConsoleLogger(levelThreshold=conf.loggingLevel, fmtStr=fmtStr)
  else:
    logger = newFileLogger(conf.loggingFile, levelThreshold=conf.loggingLevel, fmtStr=fmtStr)
    
  addHandler(logger)

  # Init Jester

  let port = Port(conf.jport)
  let settings = newSettings(port=port, # appName="wssh", # Apparently appName is deprecated in the http spec
    bindAddr=conf.jbindAddr, reusePort=conf.jreusePort, staticDir=getStaticPath()) #, numThreads=jnumThreads)

  var jester: Jester

  case conf.mode
  of Direct: # Direct mode
    jester = initJester(direct, settings=settings)

  of MultiProxy:
    discard

  # Run

  jester.serve()



when isMainModule:
  import cligen
  wsshConf = initFromCL(wsshSettingsDflt, cmdName="wssh", doc="""
  Web UI for backend SSH connections.
  """, help={
    "mode": "Options: Direct, MultiProxy. Look at README.md for more details.",
    "loggingFile": "Where to output logs to. Defaults to stdout/console.",
    "loggingLevel": "What levels of logs should written.",
    "shellWorkingDir": "The working directory of all run shell commands in direct mode. [Direct Exclusive]",
    "jport": "Which port the jester web server should use.",
    "jbindAddr": "Which address(es) should be used by the jester web server.",
    "jreusePort": "Whether jester should reuse http ports. If you don't know what this does don't touch it.",
    "jnumThreads": "In development. (In the latest commit of jester but not the release)"
  }, short={
    "shellWorkingDir": 'd',
    "loggingFile": '\0',
    "loggingLevel": '\0',
    "jport": 'p',
    "jbindAddr": 'b',
    "jreusePort": '\0',
    "jnumThreads": '\0'
  })
  main()