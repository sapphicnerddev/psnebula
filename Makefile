# A classic Makefile is something I tend to avoid, but CMake likely can't pick up on
# the compilers/tools that the PSP-SDK exposes. So I'm just going with the flow and
# running with it. This is a monolithic Makefile; so it handles everything for the
# project without using Makefile submodule files (invoked by make -C iirc)
#
# Note: Makefile syntax is... dense, and hard to parse with a glance, here be dragons!
# Note2: The PSP SDK is absolutely REQUIRED!
#

# ------------------------------------------------------------------------------
# Tools
# ------------------------------------------------------------------------------
CC  ?= psp-gcc
CXX ?= psp-g++
LD  ?= psp-ld

PSPSDK := $(shell psp-config --pspsdk-path)
PSPDEV := $(shell psp-config --pspdev-path)

# ------------------------------------------------------------------------------
# Project
# ------------------------------------------------------------------------------
TARGET_XMB = psnebula
# intermediate; each .c in src/modules → its own PRX
TARGET_MOD = nebula_modules

# ------------------------------------------------------------------------------
# Directories
# ------------------------------------------------------------------------------
SRC_DIR    = src
INC_DIR    = include
BUILD_DIR  = build
OUTPUT_DIR = output

XMB_SRC_DIR = $(SRC_DIR)/xmb
MOD_SRC_DIR = $(SRC_DIR)/modules

# ------------------------------------------------------------------------------
# Sources + objects
# ------------------------------------------------------------------------------

# XMB shell — all C/C++ under src/xmb/
XMB_SOURCES_C   := $(shell find $(XMB_SRC_DIR) -name '*.c')
XMB_SOURCES_CXX := $(shell find $(XMB_SRC_DIR) -name '*.cpp')
XMB_OBJS        := $(patsubst $(XMB_SRC_DIR)/%.c,   $(BUILD_DIR)/xmb/%.c.o,   $(XMB_SOURCES_C))
XMB_OBJS        += $(patsubst $(XMB_SRC_DIR)/%.cpp, $(BUILD_DIR)/xmb/%.cpp.o, $(XMB_SOURCES_CXX))

# Kernel modules — each .c file in src/modules/ becomes its own PRX.
MOD_SOURCES := $(shell find $(MOD_SRC_DIR) -name '*.c')
MOD_PRXS    := $(patsubst $(MOD_SRC_DIR)/%.c, $(OUTPUT_DIR)/%.prx, $(MOD_SOURCES))

# ------------------------------------------------------------------------------
# Flags
# ------------------------------------------------------------------------------
INCFLAGS = -I$(INC_DIR) \
           -I$(INC_DIR)/modules \
           -I$(INC_DIR)/utils \
           -I$(INC_DIR)/xmb \
           -I$(PSPSDK)/include

# -G0: disable GP-relative data optimisation, avoids subtle weirdness
CFLAGS   = -O2 -G0 -Wall -Wextra $(INCFLAGS)

# Apparently the PSP never had this supported so it just wastes space.
CXXFLAGS = $(CFLAGS) -fno-exceptions -fno-rtti

# XMB shell link flags
XMB_LDFLAGS = -L$(PSPSDK)/lib
XMB_LIBS    = -lpspdebug -lpspge -lpspdisplay -lpspctrl -lpspsdk -lc -lpspuser

# Kernel module link flags — modules need kernel libs + prx flag
MOD_CFLAGS  = $(CFLAGS) -DBUILDING_PRX
MOD_LDFLAGS = -L$(PSPSDK)/lib -mprx
MOD_LIBS    = -lpspdebug -lpspkernellibs -lpspsdk -lc

# ------------------------------------------------------------------------------
# PSP metadata
# ------------------------------------------------------------------------------
PSP_EBOOT_TITLE = PSNebula
PSP_EBOOT_ICON  = ICON0.PNG

# ------------------------------------------------------------------------------
# Top-level targets
# ------------------------------------------------------------------------------
.PHONY: all clean install

# Both halves are always required — shell is useless without its modules
all: eboot modules

# ------------------------------------------------------------------------------
# XMB shell → EBOOT.PBP
# ------------------------------------------------------------------------------
.PHONY: eboot

$(BUILD_DIR)/xmb/%.c.o: $(XMB_SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/xmb/%.cpp.o: $(XMB_SRC_DIR)/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(TARGET_XMB).elf: $(XMB_OBJS)
	$(CXX) $(XMB_LDFLAGS) -o $@ $^ $(XMB_LIBS)

eboot: $(TARGET_XMB).elf
	@mkdir -p $(OUTPUT_DIR)
	psp-fixup-imports $
	mksfo '$(PSP_EBOOT_TITLE)' PARAM.SFO
	pack-pbp $(OUTPUT_DIR)/EBOOT.PBP PARAM.SFO $(PSP_EBOOT_ICON) \
	         NULL NULL NULL NULL $< NULL
	@echo ">>> EBOOT.PBP written to $(OUTPUT_DIR)/"

# ------------------------------------------------------------------------------
# Kernel modules → one PRX per source file in src/modules/
# ------------------------------------------------------------------------------
.PHONY: modules

# Pattern: compile a single module source to a temporary ELF, then prxgen it
# The ELF is intermediate and lives in build/modules/
$(BUILD_DIR)/modules/%.elf: $(MOD_SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(MOD_CFLAGS) $(MOD_LDFLAGS) -o $@ $< $(MOD_LIBS)
	psp-fixup-imports $@

$(OUTPUT_DIR)/%.prx: $(BUILD_DIR)/modules/%.elf
	@mkdir -p $(OUTPUT_DIR)
	psp-prxgen $< $@
	@echo ">>> Module PRX written: $@"

modules: $(MOD_PRXS)

# ------------------------------------------------------------------------------
# Clean
# ------------------------------------------------------------------------------
clean:
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR) $(TARGET_XMB).elf PARAM.SFO
	@echo ">>> Clean done"

install: all
	@echo ">>> Install is not working at this time, please copy over manually."
