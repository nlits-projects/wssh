from macros import getProjectPath
import std/[os], jester


const wsshVersion* = "0.1.0" # Current wssh version

type WsshMode* {.pure.} = enum MultiProxy, Direct # Wssh mode enum
  
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