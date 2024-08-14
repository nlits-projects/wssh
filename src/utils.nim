from macros import getProjectPath
import os

  
proc getStaticPath*(): string =
  return absolutePath(getProjectPath() / "public")
