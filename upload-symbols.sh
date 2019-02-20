#!/usr/bin/env bash
if [[ -z $1 ]]; then
  echo "missing required configuration"
  exit 1
fi
configuration=$1

if [[ -z $2 ]]; then
  echo "missing required dSYMs directory"
  exit 2
fi
dSYMsDir=$2

Pods/Fabric/upload-symbols -gsp "CinemaKit/Assets/GoogleService-Info-$configuration.plist" -p ios $dSYMsDir
