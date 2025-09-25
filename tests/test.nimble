# Package

version = "0.0.1"
author = "Archivist core contributors"
description = "Tests for crawler for Archivist networks"
license = "MIT"
installFiles = @["build.nims"]

# Dependencies
requires "asynctest >= 0.5.2 & < 0.6.0"
requires "unittest2 <= 0.3.0"

task test, "Run tests":
  exec "nim c -r testArchivistCrawler.nim"
