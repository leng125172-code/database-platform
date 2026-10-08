#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"
compose config --quiet
compose up -d --wait

