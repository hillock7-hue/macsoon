#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p .build/module-cache

swiftc \
  -module-cache-path .build/module-cache \
  Sources/FlowInk/*.swift \
  -o .build/FlowInkPrototype

./.build/FlowInkPrototype
