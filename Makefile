# A classic Makefile is something I tend to avoid, but CMake likely can't pick up on
# the compilers/tools that the PSP-SDK exposes. So I'm just going with the flow and
# running with it. This is a monolithic Makefile; so it handles everything for the
# project without using Makefile submodule files (invoked by make -C iirc)
#
# Note: Makefile syntax is... dense, and hard to parse with a glance, here be dragons!
#

CC  ?= psp-gcc
CPP ?= psp-g++
LD  ?= psp-ld
