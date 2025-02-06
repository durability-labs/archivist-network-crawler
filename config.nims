--define:
  metrics

# switch("define", "chronicles_runtime_filtering=true")
# Sets TRACE logging for everything except DHT
switch("define", "chronicles_log_level=INFO")
# switch("define", "chronicles_disabled_topics:discv5")

when (NimMajor, NimMinor) >= (2, 0):
  --mm:
    refc
