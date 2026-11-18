#!/bin/sh
set -e
cd "$(dirname "$0")"
asciidoctor -b html5 -a toc=left -o RVM16-ISA-Manual.html RVM16-ISA-Manual.adoc
