#!/bin/sh

set -e

# This setup script is an alternative method of adjusting the tarball
# contents immediately after multistrap has unpacked the packages.

# At this stage, any operations inside the rootfs must not try to
# execute any binaries within the rootfs.

# The script is called with the following arguments:

# $1 = $DIR  - the top directory of the bootstrapped system
# $2 = $ARCH - the specified architecture, already checked with dpkg-architecture.

# setup.sh needs to be executable.
