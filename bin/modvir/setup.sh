#!/bin/bash

# Fancy way to point MIDIR to two directories higher
# Should support symlinks, spaces, etc.
MIDIR="$(dirname "$(readlink -f "$0")")/../.."
