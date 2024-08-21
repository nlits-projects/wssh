from macros import getProjectPath
import std/[os, logging], jester


const wsshVersion* = "0.1.0" # Current wssh version

type # Settings types
  WsshMode* {.pure.} = enum MultiProxy, Direct # Wssh mode enum
  WsshSettings* = object # For settings explanations please compile and run `wssh --help`
    mode* = WsshMode.Direct
    loggingFile* = ""
    when defined(release):
      loggingLevel* = lvlInfo
    else:
      loggingLevel* = lvlDebug

    # Wssh Direct settings
    shellWorkingDir* = ""

    # Jester settings
    jport* = 80
    jbindAddr* = "localhost"
    jreusePort* = false
    jnumThreads* = 0

const wsshSettingsDflt* = WsshSettings() # Defaults as an object to please cligen

when defined(threads):
  var wsshConf* {.global, threadvar.}: WsshSettings # Global project-wide settings. Copied to each threads. NOT MEANT TO BE CHANGED
else:
  var wsshConf* {.global.}: WsshSettings # Global project-wide settings

  
proc getStaticPath*(): string =
  ## Get static file path for final executable
  const prj = getProjectPath()
  result = absolutePath(prj / "public")
  echo result


import karax / [karaxdsl, vdom, vstyles]

proc renderError(code: HttpCode, message: string): string = 
  ## Render error html
  let vnode = buildHtml(html):
    body(style=style(StyleAttr.textAlign, "center")):
      h1: text $code
      h2: text message
      hr()
      p: text "WSSH " & wsshVersion
    

  result = $vnode

template respErr*(code: HttpCode, message: string): untyped =
  ## Respond with error page
  resp code, {
    "Content-Type": "text/html; charset=utf-8"
  }, renderError(code, message)