# Package

version = "0.0.1"
author = "Codex core contributors"
description = "Crawler for Codex networks"
license = "MIT"
skipDirs = @["tests"]
bin = @["codexcrawler"]

# Dependencies
requires "secp256k1#2acbbdcc0e63002a013fff49f015708522875832" # >= 0.5.2 & < 0.6.0
requires "protobuf_serialization#5a31137a82c2b6a989c9ed979bb636c7a49f570e"
  # >= 0.2.0 & < 0.3.0
requires "nimcrypto >= 0.5.4"
requires "bearssl == 0.2.5"
requires "chronicles >= 0.10.2 & < 0.11.0"
requires "chronos >= 4.0.3 & < 4.1.0"
requires "libp2p == 1.5.0"
requires "metrics#cacfdc12454a0804c65112b9f4f50d1375208dcd"
requires "stew >= 0.2.0"
requires "stint#3236fa68394f1e3a06e2bc34218aacdd2d675923"
requires "https://github.com/codex-storage/nim-datastore >= 0.1.0 & < 0.2.0"
requires "questionable >= 0.10.15 & < 0.11.0"
requires "https://github.com/codex-storage/nim-codex-dht#4bd3a39e0030f8ee269ef217344b6b59ec2be6dc"
  # 7 Jan 2024 - Support for Nim 2.0.14
requires "docopt >= 0.7.1 & < 1.0.0"
requires "nph >= 0.6.1 & < 1.0.0"

task format, "Formatting...":
  exec "nph ./"

task test, "Run tests":
  exec "nimble install -d -y"
  withDir "tests":
    exec "nimble test"
