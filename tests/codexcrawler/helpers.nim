import std/random
import pkg/stint
import ../../codexcrawler/types

proc genNid*(): Nid =
  Nid(rand(uint64).u256)
