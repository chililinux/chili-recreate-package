# chili-recreate-package

Package Recreator for Arch Linux

## Overview

Package Recreator is a bash script designed to recreate installable packages from already installed software on Arch Linux and Arch-based distributions (such as Manjaro, BigLinux, EndeavourOS, etc.). This tool is particularly useful for system administrators, package maintainers, and advanced users who need to replicate installed packages without access to the original package files.

## Version

Current version: 1.0.0

## Features

- Recreates packages from installed files
- Generates proper metadata (.PKGINFO and .MTREE files)
- Creates a compressed package file compatible with pacman
- Generates an MD5 checksum for the created package
- Supports all Arch-based distributions

## Requirements

- Arch Linux or an Arch-based distribution (Manjaro, BigLinux, etc.)
- `pacman` package manager
- `fakeroot` and `sudo` for file operations
- `bsdtar` for creating package archives

## Installation

1. Clone this repository or download the `recreate-package.sh` script.
2. Make the script executable:
   ```
   chmod +x recreate-package.sh
   ```

## Usage

Run the script with the name of the installed package you want to recreate:

```
./recreate-package.sh package_name
```

For example:
```
./recreate-package.sh firefox
```

The script will:
1. Check if the package is installed
2. List and copy all files installed by the package
3. Generate necessary metadata files
4. Create a new package file (.pkg.tar.zst)
5. Generate an MD5 checksum

The recreated package will be saved in the `~/recreated_packages` directory.

## Output

- Recreated package: `~/recreated_packages/package_name-version-arch.pkg.tar.zst`
- MD5 checksum: `~/recreated_packages/package_name-version-arch.pkg.tar.zst.md5`

## Warnings

- This script requires sudo permissions to access and copy system files.
- Recreated packages may not be identical to the original packages, especially if system configurations have been modified.
- Use recreated packages at your own risk. They are not official packages and may not include all original metadata.

## Contributing

Contributions, issues, and feature requests are welcome. Feel free to check the [issues page](https://github.com/yourusername/package-recreator/issues) if you want to contribute.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the need to recreate packages in Arch Linux environments
- Thanks to the Arch Linux community for their extensive documentation

## Disclaimer

This script is not officially associated with or endorsed by Arch Linux or any of its derivatives. Use it responsibly and at your own risk.
