stack build
./.stack-work/install/x86_64-osx/lts-2.20/7.8.4/bin/vjeranc rebuild
cp ../vjeranc.github.io/CNAME _site
cp ../vjeranc.github.io/README.md _site
rm -rf ../vjeranc.github.io/*
cp -R _site/* ../vjeranc.github.io
cd ../vjeranc.github.io
git add .
git commit -m 'update'
git push -u origin master
