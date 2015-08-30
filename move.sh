#!/usr/bin/env bash

stack build
./blog-exec.sh rebuild
cp ../vjeranc.github.io/CNAME _site
cp ../vjeranc.github.io/README.md _site
rm -rf ../vjeranc.github.io/*
cp -R _site/* ../vjeranc.github.io
cd ../vjeranc.github.io
git add .
git commit -m 'update'
git push -u origin master
