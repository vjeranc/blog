#!/usr/bin/env bash

pandoc --from=markdown --to=markdown --columns=79 $1
