#!/bin/sh
set -eu
if grep -nE '(^|[^[:alnum:]_])(sorry|admit|axiom|unsafe)([^[:alnum:]_]|$)' ./*.lean; then
  echo 'Unexpected unchecked declaration in authored Lean source' >&2
  exit 1
fi
