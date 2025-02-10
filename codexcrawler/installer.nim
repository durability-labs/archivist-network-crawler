import std/os
import pkg/chronos
import pkg/chronicles
import pkg/questionable/results

import ./config
import ./component
import ./components/dht
import ./components/crawler
import ./components/timetracker
import ./utils/keyutils
import ./utils/datastoreutils

proc initializeDht(config: Config): Future[?!Dht] {.async.} =
  without dhtStore =? createDatastore(config.dataDir / "dht"), err:
    return failure(err)
  let keyPath = config.dataDir / "privatekey"
  without privateKey =? setupKey(keyPath), err:
    return failure(err)

  var listenAddresses = newSeq[MultiAddress]()
  # TODO: when p2p connections are supported:
  # let aaa = MultiAddress.init("/ip4/" & config.publicIp & "/tcp/53678").expect("Should init multiaddress")
  # listenAddresses.add(aaa)

  var discAddresses = newSeq[MultiAddress]()
  let bbb = MultiAddress
    .init("/ip4/" & config.publicIp & "/udp/" & $config.discPort)
    .expect("Should init multiaddress")
  discAddresses.add(bbb)

  let dht = Dht.new(
    privateKey,
    bindPort = config.discPort,
    announceAddrs = listenAddresses,
    bootstrapNodes = config.bootNodes,
    store = dhtStore,
  )

  dht.updateAnnounceRecord(listenAddresses)
  dht.updateDhtRecord(discAddresses)

  return success(dht)

proc createComponents*(config: Config): Future[?!seq[Component]] {.async.} =
  var components: seq[Component] = newSeq[Component]()

  without dht =? (await initializeDht(config)), err:
    return failure(err)

  components.add(dht)
  components.add(Crawler.new(dht, config))
  components.add(TimeTracker.new(config))
  return success(components)
