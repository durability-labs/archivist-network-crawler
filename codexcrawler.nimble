# Package

version       = "0.0.1"
author        = "Codex core contributors"
description   = "Crawler for Codex networks"
license       = "MIT"
skipDirs      = @["tests"]
bin           = @["codexcrawler"]

# Dependencies
requires "secp256k1#2acbbdcc0e63002a013fff49f015708522875832" # >= 0.5.2 & < 0.6.0
requires "protobuf_serialization" # >= 0.2.0 & < 0.3.0
requires "nimcrypto >= 0.5.4"
requires "bearssl == 0.2.5"
requires "chronicles >= 0.10.2 & < 0.11.0"
requires "chronos >= 4.0.3 & < 5.0.0"
requires "libp2p == 1.5.0"
requires "metrics"
requires "stew#head"
requires "stint"
requires "https://github.com/codex-storage/nim-datastore >= 0.1.0 & < 0.2.0"
requires "questionable"
requires "https://github.com/codex-storage/nim-codex-dht"

task test, "Run tests":
  exec "nimble install -d -y"
  withDir "tests":
    exec "nimble test"
