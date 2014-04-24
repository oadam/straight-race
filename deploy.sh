#!/bin/bash
rm -rf build || exit 0;
mkdir build; 
pub build
cd build/web
git init
git config user.name "Build bot"
git config user.email "buildbot@oadam.com"
git add .
git commit -m "Deployed to Github Pages"
#git push --force --quiet "https://${GH_TOKEN}@${GH_REF}" master:gh-pages > /dev/null 2>&1
git push --force "git@github.com:oadam/straight-race.git" master:gh-pages 

