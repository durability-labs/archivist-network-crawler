import pkg/ethers
import pkg/questionable

import ./marketplace/market
import ./marketplace/marketplace
import ../config

proc aaa*(config: Config) {.async.} = 
  echo "aaa"

  let provider = JsonRpcProvider.new(config.ethProvider)
  without marketplaceAddress =? Address.init(config.marketplaceAddress):
    raiseAssert("A!")

  let marketplace = Marketplace.new(marketplaceAddress, provider)
  let market = OnChainMarket.new(marketplace)

  echo "bbb"
  echo "running with marketplace address: " & $marketplaceAddress

  try:
    without zkeyhash =? await market.getZkeyHash():
      echo "couldn't get zkeyhash"
      return
    echo "zkeyhash=" & $zkeyhash

  except CatchableError as err:
    echo "catchable error! " & err.msg

  echo "ccc"
