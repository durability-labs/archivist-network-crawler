# Archivist Network Crawler

![Crawler](crawler.png)

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)](#stability)
[![CI (GitHub Actions)](https://github.com/archivist-storage/nim-archivist-dht/workflows/CI/badge.svg?branch=master)](https://github.com/archivist-storage/nim-archivist-dht/actions/workflows/ci.yml?query=workflow%3ACI+branch%3Amaster)
[![codecov](https://codecov.io/gh/archivist-storage/nim-archivist-dht/branch/master/graph/badge.svg?token=tlmMJgU4l7)](https://codecov.io/gh/archivist-storage/nim-archivist-dht)

# !! Work in Progress !!

This project uses nim-archivist-dht, nim-libp2p, nim-ethers, and nim-metrics to create a metrics service. The crawler will traverse the Archivist network and produce metrics such as:
- Number of DHT nodes (alive vs total)
- P2P connectivity (percentage)
- Storage contract statistics (created, total size, average size, average duration, pricing information??)

Metrics are published from a scrape target.

# Usage

```sh
nimble format
nimble build
nimble test
nimble run
```
