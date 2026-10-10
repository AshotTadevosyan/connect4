#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -O Sources/ConnectFourCore/Game.swift Sources/ConnectFourCore/AI.swift Tests/ConnectFourCoreTests/GameTests.swift -o .build/CoreTests
.build/CoreTests
