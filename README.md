Proof of work for Electrum protocol
===================================

This script adds proof of work to the [Electrum protocol][1].

The idea is that the [Electrum][2] network can fight the spam in a similar
manner as was proposed for email with [hashcash][3].

Written by Luca Venturini, based on an idea of Guido Dassori, sprouted on
[Telegram Channel Bitcoin Italia][4].

The script is adapted from [tcp-proxy.pl][5] by Peteris Krumins

Strategy
--------
Instead of changing Electrum client or Electrum server, we put a proxy
between the client and the Internet, and between the Internet and the server.
The proxy on the client side calculates the proof of work and embeds it in the
JSON request. The proxy on the server side checks the POW field, strips it away
and sends to the server the same request that the client originally sent.

### Electrum

![Electrum diagram][electrum]

### Electrum-hashcash

![Electrum-hashcash diagram][electrum-hashcash]

Required libraries
------------------
```
apt-get install libjson-perl libdigest-sha-perl libstring-random-perl
```

Install on server side
----------------------
* Install [ElectrumX][6]
* Start ElectrumX on port 40001:
```
TCP_PORT=40001 COIN=Bitcoin DB_DIRECTORY=path/to/db DAEMON_URL='http://user:pass@127.0.0.1:8332/' ./electrumx_server
```
* Start the proxy, listening on port 30001:
```
git clone https://github.com/lucayepa/electrum-hashcash
cd electrum-hashcash
./tcp-proxy-server.pl --listen_port=30001 --target_host=127.0.0.1 --target_port=40001
```

Install on client side with only one server
-------------------------------------------
* Install [Electrum][7]
* Start the proxy, listening on port 50001:
```
git clone https://github.com/lucayepa/electrum-hashcash
cd electrum-hashcash
./tcp-proxy-client.pl --listen_port=50001 --target_host=my.personal.server --target_port=30001
```
* Start Electrum, using only one server, localhost on port 50001:
```
electrum -1 --server localhost:50001:t
```

Readme sources and links
------------------------
### Electrum
```
@startuml
title Electrum
node "Client" #wheat {
  left to right direction
  object RPC_client {
    Generates request
  }
}
cloud "Internet" #silver {
  object TCP {
    JSON
  }
}
node "Server" #wheat {
  object RPC_server {
    Receives request
  }
}
RPC_client --> TCP : request
TCP --> RPC_server : request
@enduml
```

### Electrum-hashcash
```
@startuml
title Electrum-hashcash
node "Client" #wheat {
  left to right direction
  object RPC_client {
    Generates request
  }
  object proxy_client #coral {
    Adds POW
  }
}
cloud "Internet" #silver {
  object TCP {
    JSON
  }
}
node "Server" #wheat {
  object proxy_server #coral {
    Checks POW
  }
  object RPC_server {
    Receives request
  }
}
RPC_client --> proxy_client : request
proxy_client --> TCP : request with POW
TCP --> proxy_server : request with POW
proxy_server --> RPC_server : request
@enduml
```

[Links]: #
[1]: https://electrumx.readthedocs.io/en/latest/protocol.html
[2]: https://electrum.org/#home
[3]: https://en.wikipedia.org/wiki/Hashcash
[4]: https://github.com/andreabenetton/BitcoinItalia
[5]: https://github.com/pkrumins/perl-tcp-proxy
[6]: https://github.com/mariodian/electrumx-no-shitcoins.git
[7]: https://electrum.org

[Images]: #
[electrum]: electrum.png
[electrum-hashcash]: electrum-hashcash.png
