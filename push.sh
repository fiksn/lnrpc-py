#!/bin/sh

# Nix was not meant for side-effects (perhaps move to Makefile)
nix --option sandbox false build .#pushDocker --no-link -L --impure --rebuild || nix --option sandbox false build .#pushDocker --no-link -L --impure
