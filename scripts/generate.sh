#! /bin/sh

while inotifywait -e modify *.typ ; do typst compile main.typ ; done

