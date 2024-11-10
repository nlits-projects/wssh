when not (defined(release) or defined(js)):
  # switch("define", "useStdLib") # For testing
  switch("threads", "off") # Prevent crashes on test device
  # switch("define", "nimDumpAsync")
  
when defined(js):
  discard
  # switch("define", "release")