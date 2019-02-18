#!/usr/bin/env bash
if [[ -z $1 ]]; then
  echo "missing required dSYMs directory"
else
  dSYMsDir=$1
  Pods/Fabric/upload-symbols -gsp CinemaKit/Assets/GoogleService-Info.plist -p ios $dSYMsDir
fi
