#!/bin/bash
cd "$(dirname "$0")"
source chandra-env/bin/activate
exec python chandra-wrapper.py
