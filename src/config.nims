when not defined(release):
  # switch("define", "useStdLib") # For testing
  switch("threads", "off") # Prevent crashes on test device
  # switch("define", "nimDumpAsync")