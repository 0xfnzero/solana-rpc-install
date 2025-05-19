#!/bin/bash

curl -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0", "id":1, "method":"getHealth"}' \
    http://127.0.0.1:8899