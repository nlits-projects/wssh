from macros import getProjectPath
import os
  
proc getStaticPath*(): string =
  const prj = getProjectPath()
  result = absolutePath(prj / "public")
  echo result