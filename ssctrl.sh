#!/bin/bash

conf=/etc/shadowsocks/shadowsocks.json

# should run as root
if [[ "$(whoami)" != "root" ]]
then
  echo "please run this as root"
  exit 1
fi

function start() {
  nohup sslocal -c $conf >/dev/null 2>&1 &
  # forward http to socks
  privoxy /etc/privoxy/config
  
  ps aux | grep -E 'sslocal|privoxy' | grep -v "grep"
}

function stop() {
  pid=`ps aux | grep sslocal | grep -v grep | awk '{print $2}'`
  
  echo "sslocal pid: $pid"
  if [ -n "$pid" ]; then
    # sslocal -c $conf -d stop
    kill -9 $pid
  fi

  pid=`ps aux | grep privoxy | grep -v grep | awk '{print $2}'`
  
  echo "privoxy pid: $pid"
  if [ -n "$pid" ]; then
    kill -9 $pid
  fi

  # ps aux | grep -E 'sslocal|privoxy' | grep -v "grep"
}

function restart() {
  stop
  start
}

init() {
  # check if shadowsocks installed
  if hash pip 2>/dev/null; then
    if [ $(pip show shadowsocks | grep -a -m 1 Version | wc -l) == 1 ]; then
      echo "shadowsocks has already been installed."
      exit 0
    fi
  fi
  yum -y install epel-release
  yum -y install python-pip
  pip install --upgrade pip
  pip install shadowsocks

  server_config='{"server":"jp1-vip2.1x6kp.pw","server_port":51124,"local_address":"127.0.0.1","local_port":1086,"password":"pVAGMXX84kzn","timeout":300,"method":"chacha20-ietf-poly1305","workers":1,"fast_open":false}'
  # https://github.com/shadowsocks/shadowsocks/wiki/Configuration-via-Config-File
  # {
  #   "server":"jp1-vip2.1x6kp.pw",
  #   "server_port": 51124,
  #   "local_address": "127.0.0.1",
  #   "local_port": 1086,
  #   "password": "pVAGMXX84kzn"
  #   "timeout": 300,
  #   "method": "chacha20-ietf-poly1305",
  #   "workers": 1,
  #   "fast_open": false
  # }
  mkdir -p /etc/shadowsocks
  echo $server_config | python -m json.tool | tee /etc/shadowsocks/shadowsocks.json

  # chacha20-ietf-poly1305
  # https://github.com/shadowsocksrr/shadowsocks-rss/wiki/libsodium
  yum -y install libsodium

  # privoxy
  yum -y install privoxy
  # vi /etc/privoxy/config
  # config
  # listen-address 127.0.0.1:8118
  # forward-socks5t / 127.0.0.1:1086 .
  sed -i -E 's/#[ ]*listen-address[ ]*127.0.0.1:8118/listen-address 127.0.0.1:8118/g' /etc/privoxy/config
  sed -i -E 's/#[ ]*forward-socks5t[ ]*\/[ ]*127.0.0.1:[0-9]* ./forward-socks5t \/ 127.0.0.1:1086 ./g' /etc/privoxy/config
}

# function http_proxy_start() {
#   export http_proxy=http://127.0.0.1:8118;
#   export https_proxy=http://127.0.0.1:8118;

#   echo "http_proxy $http_proxy"
#   echo "https_proxy $https_proxy"
# }
# function http_proxy_stop() {
#   unset http_proxy https_proxy
#   echo "http_proxy $http_proxy"
#   echo "https_proxy $https_proxy"
# }

case $1 in
  start)
  start
  ;;

  stop)
  stop
  ;;

  restart)
  restart
  ;;

  *)
  init
  ;;
esac
exit 0
