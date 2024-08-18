from macros import getProjectPath
import os

type WsshMode* {.pure.} = enum MultiProxy, Direct 
  
proc getStaticPath*(): string =
  const prj = getProjectPath()
  result = absolutePath(prj / "public")
  echo result