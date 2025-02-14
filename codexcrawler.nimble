# Package

version = "0.0.1"
author = "Codex core contributors"
description = "Crawler for Codex networks"
license = "MIT"
skipDirs = @["tests"]
bin = @["codexcrawler"]
binDir = "build"

# Dependencies
requires "nim >= 2.0.14 & < 3.0.0"
requires "secp256k1 >= 0.6.0 & < 0.7.0"
requires "protobuf_serialization >= 0.3.0 & < 0.4.0"
requires "nimcrypto >= 0.6.2 & < 0.7.0"
requires "bearssl >= 0.2.5 & < 0.3.0"
requires "chronicles >= 0.10.2 & < 0.11.0"
requires "chronos >= 4.0.3 & < 4.1.0"
requires "libp2p >= 1.5.0 & < 2.0.0"
requires "metrics >= 0.1.0 & < 0.2.0"
requires "stew >= 0.2.0 & < 0.3.0"
requires "stint >= 0.8.1 & < 0.9.0"
requires "https://github.com/codex-storage/nim-datastore >= 0.2.0 & < 0.3.0"
requires "questionable >= 0.10.15 & < 0.11.0"
requires "https://github.com/codex-storage/nim-codex-dht#f6eef1ac95c70053b2518f1e3909c909ed8701a6"
requires "docopt >= 0.7.1 & < 1.0.0"
requires "nph >= 0.6.1 & < 1.0.0"

task format, "Formatting...":
  exec "nph ./"

task test, "Run tests":
  exec "nimble install -d -y"
  withDir "tests":
    exec "nimble test"
