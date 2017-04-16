#!/bin/bash
./configure
mv Makefile PKGBUILD
makepkg -f
