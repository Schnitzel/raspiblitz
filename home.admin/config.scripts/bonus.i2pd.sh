#!/bin/bash

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "# bonus.i2pd.sh on       -> install the i2pd"
  echo "# bonus.i2pd.sh off      -> uninstall the i2pd"
  echo "# bonus.i2pd.sh addseednodes -> Add all I2P seed nodes from: https://github.com/bitcoin/bitcoin/blob/master/contrib/seeds/nodes_main.txt"
  exit 1
fi

function add_repo {
  # Add repo for the latest version
  # i2pd — https://repo.i2pd.xyz/.help/readme.txt
  # https://repo.i2pd.xyz/.help/add_repo

  source /etc/os-release
  DIST=$ID
  case $ID in
    debian|ubuntu|raspbian)
      if [[ -n $DEBIAN_CODENAME ]]; then
        VERSION_CODENAME=$DEBIAN_CODENAME
      fi
      if [[ -n $UBUNTU_CODENAME ]]; then
        VERSION_CODENAME=$UBUNTU_CODENAME
      fi
      if [[ -z $VERSION_CODENAME ]]; then
        echo "Couldn't find VERSION_CODENAME in your /etc/os-release file. Did your system supported? Please report issue to me by writing to email: 'r4sas <at> i2pd.xyz'"
        exit 1
      fi
      RELEASE=$VERSION_CODENAME
    ;;
    *)
      if [[ -z $ID_LIKE || "$ID_LIKE" != "debian" && "$ID_LIKE" != "ubuntu" ]]; then
        echo "Your system is not supported by this script. Currently it supports debian-like and ubuntu-like systems."
        exit 1
      else
        DIST=$ID_LIKE
        case $ID_LIKE in
          debian)
            if [[ "$ID" == "kali" ]]; then
              if [[ "$VERSION" == "2019"* || "$VERSION" == "2020"* ]]; then
                RELEASE="buster"
              elif [[ "$VERSION" == "2021"* || "$VERSION" == "2022"* ]]; then
                RELEASE="bullseye"
              fi
            else
              RELEASE=$DEBIAN_CODENAME
            fi
          ;;
          ubuntu)
            RELEASE=$UBUNTU_CODENAME
          ;;
        esac
      fi
      ;;
    esac
  if [[ -z $RELEASE ]]; then
    echo "Couldn't detect your system release. Please report issue to me by writing to email: 'r4sas <at> i2pd.xyz'"
    exit 1
  fi
  echo "Importing signing key"
  wget -q -O - https://repo.i2pd.xyz/r4sas.gpg | sudo apt-key --keyring /etc/apt/trusted.gpg.d/i2pd.gpg add -
  echo "Adding APT repository"
  echo "deb https://repo.i2pd.xyz/$DIST $RELEASE main" | sudo tee /etc/apt/sources.list.d/i2pd.list
  echo "deb-src https://repo.i2pd.xyz/$DIST $RELEASE main" | sudo tee -a /etc/apt/sources.list.d/i2pd.list
}


echo "# Running: 'bonus.i2pd.sh $*'"
source /mnt/hdd/raspiblitz.conf

isInstalled=$(systemctl is-active --quiet i2pd.service)
isRunning=$(systemctl status i2pd 2>/dev/null | grep -c 'active (running)')

if [ "$1" = "1" ] || [ "$1" = "on" ]; then

  # dont run install if already installed
  if [ ${isInstalled} -gt 0 ]; then
    echo "# i2pd.service is already installed."
    exit 1
  fi

echo "# Installing i2pd ..."

  add_repo

  sudo apt-get update
  sudo apt-get install -y i2pd
  sudo systemctl enable i2pd

  /home/admin/config.scripts/blitz.conf.sh set debug tor /mnt/hdd/bitcoin/bitcoin.conf noquotes
  /home/admin/config.scripts/blitz.conf.sh add debug i2p /mnt/hdd/bitcoin/bitcoin.conf noquotes
  /home/admin/config.scripts/blitz.conf.sh set ipsam 127.0.0.1:7656 /mnt/hdd/bitcoin/bitcoin.conf noquotes
  /home/admin/config.scripts/blitz.conf.sh set i2pacceptincoming 1 /mnt/hdd/bitcoin/bitcoin.conf noquotes
  /home/admin/config.scripts/blitz.conf.sh set onlynet tor /mnt/hdd/bitcoin/bitcoin.conf noquotes
  /home/admin/config.scripts/blitz.conf.sh add onlynet i2p /mnt/hdd/bitcoin/bitcoin.conf noquotes

  # Restart bitcoind and start i2p
  source <(/home/admin/_cache.sh get state)
  if [ "${state}" == "ready" ]; then
    sudo systemctl restart bitcoind 2>/dev/null
    sleep 10

    echo "# starting i2pd service ..."
    sudo systemctl start i2pd

    echo "# monitor i2p in bitcoind"
    sudo tail -n 100 /mnt/hdd/bitcoin/debug.log | grep i2p
    bitcoin-cli -netinfo 4
  fi

  if i2pd --version; then
    echo "# Installed i2pd"
  else
    echo "# i2pd is not installed"
    exit 1
  fi

  # setting value in raspiblitz.conf
  /home/admin/config.scripts/blitz.conf.sh set i2pd "on"

  exit 0
fi

if [ "$1" = "addseednodes" ]; then

  /home/admin/conf.scripts/bonus.i2pd.sh on

  echo "Add all I2P seed nodes from: https://github.com/bitcoin/bitcoin/blob/master/contrib/seeds/nodes_main.txt"
  i2pSeedNodeList=$(curl -sS https://raw.githubusercontent.com/bitcoin/bitcoin/master/contrib/seeds/nodes_main.txt | grep .b32.i2p:0)
  for i2pSeedNode in ${i2pSeedNodeList}; do
    bitcoin-cli addnode "$i2pSeedNode" "onetry"
  done
  echo
  echo "# Display sudo tail -n 100 /mnt/hdd/bitcoin/debug.log | grep i2p"
  sudo tail -n 100 /mnt/hdd/bitcoin/debug.log | grep i2p
  echo
  echo "# Display bitcoin-cli -netinfo 4"
  bitcoin-cli -netinfo 4
fi

# switch off
if [ "$1" = "0" ] || [ "$1" = "off" ]; then

  echo "# stop & remove systemd service"
  sudo systemctl stop i2pd 2>/dev/null
  sudo systemctl disable i2pd.service

  echo "# Uninstall with apt"
  sudo apt remove -y i2pd

  echo "# Remove settings from bitcoind"
  /home/admin/config.scripts/blitz.conf.sh delete debug /mnt/hdd/bitcoin/bitcoin.conf
  /home/admin/config.scripts/blitz.conf.sh set debug tor /mnt/hdd/bitcoin/bitcoin.conf
  /home/admin/config.scripts/blitz.conf.sh delete ipsam /mnt/hdd/bitcoin/bitcoin.conf
  /home/admin/config.scripts/blitz.conf.sh delete i2pacceptincoming  /mnt/hdd/bitcoin/bitcoin.conf
  /home/admin/config.scripts/blitz.conf.sh delete onlynet  /mnt/hdd/bitcoin/bitcoin.conf
  /home/admin/config.scripts/blitz.conf.sh set onlynet tor /mnt/hdd/bitcoin/bitcoin.conf

  sudo rm /etc/systemd/system/i2pd.service

  if ! i2pd --version 2>/dev/null; then
    echo "# OK - i2pd is not installed now"
  else
    echo "# i2pd is still installed"
    exit 1
  fi

  # setting value in raspiblitz.conf
  /home/admin/config.scripts/blitz.conf.sh set i2pd "off"

  exit 0
fi

echo "# FAIL - Unknown Parameter $1"
exit 1