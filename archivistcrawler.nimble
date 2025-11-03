# Package

version = "0.0.1"
author = "Archivist core contributors"
description = "Crawler for Archivist networks"
license = "MIT"
skipDirs = @["tests"]
bin = @["archivistcrawler"]
binDir = "build"

requires "https://github.com/durability-labs/nim-libp2p#multihash-poseidon2"
requires "https://github.com/durability-labs/archivist-dht >= 0.7.1"
requires "https://github.com/durability-labs/nim-ethers >= 3.1.0"
requires "https://github.com/status-im/nim-toml-serialization >= 0.2.14"
requires "https://github.com/durability-labs/nim-datastore >= 0.4.0"
requires "https://github.com/durability-labs/nim-chronicles#version-0-12-3-pre" # TODO: update to version 0.12.3 once it is released

# requires "nim >= 2.0.14 & < 3.0.0"
# requires "secp256k1 >= 0.6.0 & < 0.7.0"
# requires "nimcrypto >= 0.6.2 & < 0.7.0"
# requires "bearssl >= 0.2.5 & < 0.3.0"
# requires "chronos >= 4.0.3 & < 4.1.0"
# requires "https://github.com/archivist-storage/nim-poseidon2#4e2c6e619b2f2859aaa4b2aed2f346ea4d0c67a3"
# requires "metrics >= 0.1.0 & < 0.2.0"
# requires "stew >= 0.2.0 & < 0.3.0"
# requires "stint >= 0.8.1 & < 0.9.0"
# requires "questionable >= 0.10.15 & < 0.11.0"
# requires "docopt >= 0.7.1 & < 1.0.0"
# requires "nph >= 0.6.1 & < 1.0.0"

task format, "Formatting...":
  exec findExe("nph") & " ./"

task test, "Run tests":
  exec "nimble install -d -y"
  withDir "tests":
    exec "nimble test"
