#!/bin/bash

cat /banner.txt
cat /version.txt

echo ""
echo "alias - show list of command shortcuts"
echo "ll - list files in current directory"
echo "tree [path] - show directory and file tree of current or specified path"
echo ""

ls -alh --color=auto
