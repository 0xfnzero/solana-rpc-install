#!/bin/bash

sudo systemctl stop sol
sudo rm -rf /root/sol/snapshot/*
sudo find /root/sol/ledger/ -mindepth 1 -not -name 'contact-info.bin' -delete
cd /root/sol/snapshot && aria2c -x16 -s16 --force-sequential=true https://snapshots.avorio.network/mainnet-beta/snapshot.tar.bz2 https://snapshots.avorio.network/mainnet-beta/incremental-snapshot.tar.bz2
sudo systemctl start sol