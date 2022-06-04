#!/usr/bin/env bash
args=$@
sbt -v "test:runMain GPU.Launcher $args"
