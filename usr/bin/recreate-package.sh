#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# shellcheck shell=bash disable=SC1091,SC2039,SC2166
#
#  recreate-package.sh - Script to recreate a package from installed files
#  Created: 2024/11/19 - 12:01
#  Altered: 2024/11/19 - 12:01
#
#  Copyright (c) 2024-2024, Tales A. Mendonça (talesam@gmail.com)
#  Copyright (c) 2024-2024, Vilmar Catafesta <vcatafesta@gmail.com>
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AS IS'' AND ANY EXPRESS OR
#  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
#  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
#  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##############################################################################
# Define colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
nc='\033[0m' # No Color

# Check if the user provided a package name
if [ -z "$1" ]; then
	echo -e "${red}Error: No package name provided.${nc}"
	echo "Usage: $0 package_name"
	exit 1
fi

package="$1"

# Temporary working directory
workDir="$HOME/recreate_package_$package"

# Directory to store recreated packages
outputDir="$HOME/recreated_packages"

pkgDir="$workDir/pkg"
fileList="$workDir/file_list.txt"
relativeFileList="$workDir/relative_file_list.txt"
pkgInfo="$pkgDir/.PKGINFO"
mTree="$pkgDir/.MTREE"

echo -e "${yellow}Recreating package '$package'...${nc}"

# Step 1: Check if the package is installed
if ! pacman -Q "$package" &>/dev/null; then
	echo -e "${red}Error: Package '$package' is not installed on the system.${nc}"
	exit 1
fi

# Create working directory and output directory
mkdir -p "$pkgDir"
mkdir -p "$outputDir"

# Step 2: List all files installed by the package
echo -e "${green}Listing files installed by the package...${nc}"
pacman -Qlq "$package" >"$fileList"
if [ $? -ne 0 ]; then
	echo -e "${red}Error listing package files.${nc}"
	exit 1
fi

# Create list of files with relative paths
sed 's|^/||' "$fileList" >"$relativeFileList"

# Step 3: Copy files to the pkg directory using sudo
echo -e "${green}Copying files to the packaging directory...${nc}"
totalSize=0
while IFS= read -r file; do
	if [ -f "/$file" ]; then
		dir=$(dirname "$file")
		sudo mkdir -p "$pkgDir/$dir"
		sudo cp -a "/$file" "$pkgDir/$dir/"
		fileSize=$(du -b "/$file" | cut -f1)
		totalSize=$((totalSize + fileSize))
		echo "Copied: /$file ($(numfmt --to=iec-i --suffix=B --format="%.2f" $fileSize))"
	elif [ -d "/$file" ]; then
		sudo mkdir -p "$pkgDir/$file"
		echo "Created directory: /$file"
	fi
done <"$relativeFileList"

echo "Total size of copied files: $(numfmt --to=iec-i --suffix=B --format="%.2f" $totalSize)"

# Adjust permissions of copied files to the current user
sudo chown -R $(whoami):$(whoami) "$pkgDir"

# Step 4: Create the .PKGINFO file
echo -e "${green}Creating .PKGINFO file...${nc}"
# Use LANG=C to ensure pacman output is in English
pkgVer=$(LANG=C pacman -Qi "$package" | grep "^Version" | awk '{print $3}')
pkgDesc=$(LANG=C pacman -Qi "$package" | grep "^Description" | cut -d ':' -f2- | sed 's/^ //')
url=$(LANG=C pacman -Qi "$package" | grep "^URL" | awk '{print $3}')
license=$(LANG=C pacman -Qi "$package" | grep "^Licenses" | cut -d ':' -f2- | sed 's/^ //')
arch=$(uname -m)
size=$(du -bs "$pkgDir" | cut -f1)
buildDate=$(date +%s)
packager="$(whoami) <$(whoami)@$(hostname)>"
depends=$(LANG=C pacman -Qi "$package" | grep "^Depends On" | cut -d ':' -f2- | sed 's/^ //' | sed 's/None//')

cat <<EOF >"$pkgInfo"
# Generated by recreate-package.sh v1.0.1
pkgname = $package
pkgver = $pkgVer
pkgdesc = $pkgDesc
url = $url
builddate = $buildDate
packager = $packager
size = $size
arch = $arch
license = $license
EOF

# Add dependencies
if [ -n "$depends" ]; then
	echo "$depends" | tr ' ' '\n' | while read -r depend; do
		if [ -n "$depend" ]; then
			echo "depend = $depend" >>"$pkgInfo"
		fi
	done
fi

# Step 5: Create the .MTREE file
echo -e "${green}Creating .MTREE file...${nc}"
cd "$pkgDir" || exit 1
LANG=C bsdtar -c --format=mtree \
	--options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' \
	. >"$mTree"

if [ $? -ne 0 ]; then
	echo -e "${red}Error creating .MTREE file.${nc}"
	exit 1
fi

# Generate date and time in the desired format
date=$(date +%y.%m.%d)
time=$(date +%H%M)

# Define the final package name with date, time, and architecture
finalPackage="${outputDir}/${package}-${pkgVer}-${arch}.pkg.tar.zst"

# Step 6: Package the files using fakeroot
echo -e "${green}Creating the package...${nc}"
cd "$pkgDir" || exit 1
fakeroot -- env LANG=C bsdtar -c --zstd -f "$finalPackage" .PKGINFO .MTREE *

if [ $? -ne 0 ]; then
	echo -e "${red}Error creating the package.${nc}"
	exit 1
fi

# Step 7: Generate the .md5 file
echo -e "${green}Generating .md5 file...${nc}"
md5sum "$finalPackage" >"${finalPackage}.md5"
if [ $? -ne 0 ]; then
	echo -e "${red}Error generating .md5 file.${nc}"
	exit 1
fi

# Step 8: Verify the created package
if [ -f "$finalPackage" ]; then
	echo -e "${green}Package created successfully: ${finalPackage}${nc}"
	echo -e "${green}.md5 file created: ${finalPackage}.md5${nc}"
	echo -e "${yellow}To install the package, run:${nc}"
	echo "sudo pacman -U $finalPackage"

	# Show the size of the created package
	packageSize=$(du -h "$finalPackage" | cut -f1)
	echo -e "${green}Size of created package: ${packageSize}${nc}"
else
	echo -e "${red}Error: Package was not created.${nc}"
	exit 1
fi

# Clean up temporary files (optional)
read -p "Do you want to remove temporary files? [y/N]: " response
if [[ "$response" =~ ^([yY])$ ]]; then
	sudo rm -rf "$workDir"
	echo -e "${green}Temporary files removed.${nc}"
else
	echo -e "${yellow}Temporary files kept in $workDir.${nc}"
fi

exit 0
