--define:
  metrics
# switch("define", "chronicles_runtime_filtering=true")
switch("define", "chronicles_log_level=TRACE")

when (NimMajor, NimMinor) >= (2, 0):
  --mm:refc
