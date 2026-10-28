# SPDX-License-Identifier: BSD-2-Clause
# L4Ka::Pistachio - direct, out-of-tree GNU Make build.
# Run "make help" for supported profiles. No CML2, Perl, or configure step.
.DEFAULT_GOAL := all
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
KERNEL := $(ROOT)/kernel
ARCH ?= x86
PROFILE ?= x86-x64-p4-nokdb
SUBARCH ?= $(word 2,$(subst -, ,$(PROFILE)))
CPU ?= $(word 3,$(subst -, ,$(PROFILE)))
PLATFORM ?= pc99
# Some build environments export PLATFORM=linux/amd64; never mistake host
# platform metadata for an L4 target platform.
ifeq ($(origin PLATFORM),environment)
PLATFORM := pc99
endif
API := v4
SCHED ?= rr
OUT ?= $(ROOT)/build/$(PROFILE)
OUT := $(abspath $(OUT))
CONFIG_DIR := $(KERNEL)/config/profiles/$(PROFILE)

# The profile is a pre-generated, checked-in configuration, not a generated
# dependency on the discontinued Python-2 CML2 package.
ifeq ($(filter help clean profiles,$(MAKECMDGOALS)),)
ifneq ($(SUBARCH),$(word 2,$(subst -, ,$(PROFILE))))
$(error PROFILE=$(PROFILE) conflicts with SUBARCH=$(SUBARCH))
endif
ifneq ($(CPU),$(word 3,$(subst -, ,$(PROFILE))))
$(error PROFILE=$(PROFILE) conflicts with CPU=$(CPU))
endif
ifeq ($(wildcard $(CONFIG_DIR)/config.h),)
$(error Unsupported PROFILE=$(PROFILE). Run 'make profiles')
endif
endif

CXX ?= g++
# GNU Make has builtin CC=cc; override only when not passed by the caller.
ifeq ($(origin CC),default)
CC := gcc
endif
LD ?= ld
ifeq ($(origin LD),default)
LD := ld
endif
NM ?= nm
OBJCOPY ?= objcopy
AWK ?= awk
SED ?= sed

# Keep both the build output and all temporary generated files out of source.
BUILDDIR := $(OUT)
SRCDIR := $(KERNEL)
CONFIG := $(OUT)/config/config.h
CONFIG_MK := $(OUT)/config/.config
INCDIR := $(OUT)/include

# Include existing source manifests, *not* the legacy Makeconf build engine.
# Explicitly set the arch- and subarch-specific directories.
SRCSRC := src/generic src/platform/$(PLATFORM) src/api/$(API) \
 src/api/$(API)/sched-$(SCHED) src/arch/x86/$(SUBARCH) \
 src/glue/$(API)-x86 src/glue/$(API)-x86/$(SUBARCH) \
 src/arch/x86 src/glue/$(API)-$(PLATFORM)
# Source manifests still use CONFIG_* and CONFIG_DEBUG build conditionals.
# These are read from checked-in known-good profile values.
-include $(CONFIG_DIR)/.config
ifeq ($(CONFIG_DEBUG),y)
SRCSRC += kdb/generic kdb/platform/$(PLATFORM) kdb/api/$(API) \
 kdb/arch/x86 kdb/arch/x86/$(SUBARCH) \
 kdb/glue/$(API)-x86 kdb/glue/$(API)-x86/$(SUBARCH) kdb
endif
MANIFESTS := $(foreach d,$(filter-out kdb,$(SRCSRC)),$(wildcard $(KERNEL)/$(d)/Makeconf))
# Most Makeconfs are declarative SOURCES += ...; a few also define legacy
# recipes for relative targets. Those are never invoked from this Makefile.
include $(MANIFESTS)
ifeq ($(SUBARCH),x32)
SOURCES += src/runtime/udivdi3.c
endif
SOURCES := $(sort $(SOURCES))
OBJS := $(addprefix $(OUT)/,$(addsuffix .o,$(basename $(SOURCES))))
DEPS := $(OBJS:.o=.d)
KERNEL_ELF := $(OUT)/$(ARCH)-kernel

# C++11 is the conservative baseline: the code predates newer language APIs.
# GNU inline assembly and linker sections remain architecture necessities.
CXXSTD ?= c++11
COMMON_FLAGS := -ffreestanding -fno-pic -fno-pie -fno-stack-protector \
 -fno-builtin -fno-omit-frame-pointer -fno-exceptions -fno-rtti \
 -fno-threadsafe-statics -Wall -Wno-unused-parameter
CPUFLAGS_x64 := -m64 -mcmodel=kernel -mno-red-zone
CPUFLAGS_x32 := -m32 -mpreferred-stack-boundary=2
CPUFLAGS := $(CPUFLAGS_$(SUBARCH)) -mno-mmx -mno-sse -mno-sse2 -mno-sse3
OPT ?= -O2
CC_INC := $(shell $(CXX) -print-file-name=include)
PPFLAGS := -nostdinc -I$(INCDIR) -I$(KERNEL)/src -I$(KERNEL)/src/generic \
 -I$(CC_INC) \
 -U$(ARCH) -U$(SUBARCH) -U$(CPU) -U$(PLATFORM) -U$(API) -U$(SCHED) \
 -D__ARCH__=$(ARCH) -D__SUBARCH__=$(SUBARCH) -D__CPU__=$(CPU) \
 -D__PLATFORM__=$(PLATFORM) -D__API__=$(API) -D__SCHED__=$(SCHED) \
 -imacros $(CONFIG) -imacros $(KERNEL)/src/generic/macros.h \
 -include $(KERNEL)/src/generic/config.h
CXXFLAGS += -std=$(CXXSTD) $(COMMON_FLAGS) -fno-rtti -fno-exceptions -fno-threadsafe-statics $(CPUFLAGS) $(OPT)
CFLAGS += -std=c11 $(filter-out -fno-rtti -fno-exceptions -fno-threadsafe-statics,$(COMMON_FLAGS)) $(CPUFLAGS) $(OPT)
ASFLAGS += $(CPUFLAGS) -fno-pie -fno-pic
LDFLAGS_x64 := -m elf_x86_64 -z max-page-size=4096 -n
LDFLAGS_x32 := -m elf_i386 -z max-page-size=4096
.PHONY: all help profiles clean distclean check-tools test
all: $(KERNEL_ELF)
help:
	@printf '%s\n' 'L4Ka::Pistachio modern build (x86 only)' \
	 ' make                                  Build default x86-64 p4 no-KDB kernel' \
	 ' make PROFILE=x86-x32-p4-nokdb' \
	 ' make PROFILE=x86-x64-p4-debug          Build x86-64 with original KDB config' \
	 ' make clean                            Remove build outputs' \
	 ' make check-tools                      Verify toolchain availability' \
	 ' make -j$$(nproc)                       Parallel build' \
	 ' make test                             Run host-side arithmetic test' \
	 ' make userland                         Build kickstart + sigma0 + pingpong' \
	 ' make l4test                           Build L4 API test root task' \
	 ' make bootfiles                        Stage QEMU/GRUB boot modules' \
	 ' make bootcheck                        Validate staged ELF module types' \
	 ' make qemu-iso                         Create a GRUB Multiboot ISO' \
	 ' make qemu                             Run BIOS/TCG QEMU' \
	 ' Override CXX, CC, LD, NM, OBJCOPY, OUT or OPT if needed.'
profiles:
	@find $(KERNEL)/config/profiles -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
test:
	@mkdir -p $(OUT)/tests
	$(CC) -std=c11 -O2 -Wall -Wextra -DPISTACHIO_TEST_UDIVDI3 $(ROOT)/tests/udivdi3_test.c -o $(OUT)/tests/udivdi3_test
	@$(OUT)/tests/udivdi3_test

check-tools:
	@$(CXX) --version | head -1
	@$(CC) --version | head -1
	@$(LD) --version | head -1
	@$(NM) --version | head -1
	@$(OBJCOPY) --version | head -1

$(CONFIG): $(CONFIG_DIR)/config.h
	@mkdir -p $(@D) $(INCDIR)
	@cp $< $@
$(CONFIG_MK): $(CONFIG_DIR)/.config
	@mkdir -p $(@D)
	@cp $< $@

# Deterministic metadata: replace the old per-build increment and host leakage.
$(INCDIR)/version.h: $(KERNEL)/../user/configure.in
	@mkdir -p $(@D)
	@{ printf '/* Generated kernel release metadata. */\n'; \
	   printf '#define KERNEL_VERSION 0\n#define KERNEL_SUBVERSION 4\n#define KERNEL_SUBSUBVERSION 0\n'; \
	   printf '#define KERNELGENDATE SHUFFLE3(day:12,month:3,year:14)\n'; \
	   printf '#define __USER__ "reproducible"\n#define __KERNELBUILDNO__ 1\n'; \
	 } > $@.tmp
	@mv $@.tmp $@

# Headers with compiler-derived layout constants must precede ALL translation
# units, including parallel jobs. Use a separate bootstrap compile.
$(INCDIR)/tcb_layout.h: $(CONFIG) $(KERNEL)/src/api/v4/tcb.h \
 $(KERNEL)/src/api/v4/sktcb.h $(KERNEL)/src/glue/v4-x86/ktcb.h \
 $(KERNEL)/src/glue/v4-x86/utcb.h
	@mkdir -p $(@D) $(OUT)/generated
	@printf '/* bootstrap for offset calculation */\n' > $@
	@{ printf '#include INC_API(tcb.h)\n'; \
	   printf 'tcb_t tcb; utcb_t utcb;\n'; \
	   printf '#define O(sym,val) __asm__ __volatile__("\\n#define " MKSTR(sym) " %%0 " : : "i"(val))\n'; \
	   printf 'void generated_offsets() {\n'; \
	   for spec in 'api/v4/tcb.h TCB tcb_t,' 'glue/v4-x86/ktcb.h TCB_ARCH tcb_t,arch.' 'api/v4/sktcb.h TCB_SCHED_STATE tcb_t,sched_state.' 'glue/v4-x86/utcb.h UTCB utcb_t,'; do \
	     set -- $$spec; hdr=$$1; prefix=$$2; object=$$3; \
	     $(AWK) '/TCB_END_MARKER/ {inside=0} inside {print} /TCB_START_MARKER/ {inside=1}' $(KERNEL)/src/$$hdr | \
	     $(CXX) -E -x c++ -P -imacros $(CONFIG) - | \
	     $(AWK) -v p="$$prefix" -v obj="$$object" '/;[[:space:]]*$$/ {gsub(/\[[^]]*\]/,"",$$0); sub(/;.*/,"",$$0); if(match($$0,/[A-Za-z_][A-Za-z_0-9]*[[:space:]]*$$/)) {n=substr($$0,RSTART,RLENGTH); gsub(/[[:space:]]/,"",n);print "O(OFS_"p"_"toupper(n)",offsetof("obj n"));"}}'; \
	   done; \
	   printf '}\n'; \
	 } > $(OUT)/generated/layout.cc
	@$(CXX) $(PPFLAGS) -include $(KERNEL)/src/generic/types.h $(CXXFLAGS) -w \
	 -DBUILD_TCB_LAYOUT -Dprivate=public -Dprotected=public -S $(OUT)/generated/layout.cc -o $(OUT)/generated/layout.s || { rm -f $@; exit 1; }
	@{ printf '#ifndef PISTACHIO_GENERATED_TCB_LAYOUT_H\n#define PISTACHIO_GENERATED_TCB_LAYOUT_H\n'; \
	 $(SED) -n -e '/^#define OFS_/ {s/[$$]//g;p;}' $(OUT)/generated/layout.s; \
	 printf '#endif\n'; } > $@.tmp
	@test $$(grep -c '^#define OFS_' $@.tmp) -gt 1 || { echo 'No TCB offsets produced' >&2; rm -f $@; exit 1; }
	@mv $@.tmp $@

# Compile the original MKASMSYM constants then reconstruct their values from
# ELF symbol sizes; uses standard GNU nm + POSIX awk, not Perl.
$(INCDIR)/asmsyms.h: $(CONFIG) $(INCDIR)/tcb_layout.h \
 $(KERNEL)/src/glue/v4-x86/asmsyms.cc $(ROOT)/mk/asm-symbols.awk
	@mkdir -p $(@D) $(OUT)/generated
	@$(CXX) $(PPFLAGS) -include $(KERNEL)/src/generic/types.h $(CXXFLAGS) \
	 -c $(KERNEL)/src/glue/v4-x86/asmsyms.cc -o $(OUT)/generated/asmsyms.o
	@{ printf '#ifndef PISTACHIO_GENERATED_ASMSYMS_H\n#define PISTACHIO_GENERATED_ASMSYMS_H\n'; \
	 $(NM) --radix=d -S $(OUT)/generated/asmsyms.o | $(AWK) -f $(ROOT)/mk/asm-symbols.awk; \
	 printf '#endif\n'; } > $@.tmp
	@mv $@.tmp $@

# The old KDB prototype scanner relied on Perl; POSIX awk is enough here.
ifeq ($(CONFIG_DEBUG),y)
KDB_SOURCES := $(addprefix $(KERNEL)/,$(filter kdb/%,$(SOURCES)))
$(INCDIR)/kdb_class_helper.h: $(KDB_SOURCES) $(KERNEL)/src/kdb/cmd.h $(CONFIG)
	@mkdir -p $(@D)
	@{ printf '/* Generated KDB command declarations. */\n'; \
	  $(AWK) '/^[[:space:]]*DECLARE_CMD[[:space:]]*\(/ { \
	    line=$$0; sub(/^[[:space:]]*DECLARE_CMD[[:space:]]*\(/,"",line); \
	    sub(/,.*/, "", line); gsub(/[[:space:]]/,"",line); \
	    print "static cmd_ret_t " line "(cmd_group_t*);" \
	  }' $(KDB_SOURCES) $(KERNEL)/src/kdb/cmd.h; \
	} > $@.tmp
	@mv $@.tmp $@
$(INCDIR)/kdb_autogenerated_protos.h: $(KDB_SOURCES) $(CONFIG)
	@mkdir -p $(@D)
	@{ printf '/* Generated KDB member prototypes. */\n'; \
	  $(AWK) '/ kdb_t::.*\(/ { \
	    line=$$0; sub(/kdb_t::/, "", line); sub(/\)[^)]*$$/, ");", line); \
	    print line \
	  }' $(filter %.cc,$(KDB_SOURCES)); \
	} > $@.tmp
	@mv $@.tmp $@
KDB_HEADERS := $(INCDIR)/kdb_class_helper.h $(INCDIR)/kdb_autogenerated_protos.h
endif

GENERATED_HEADERS := $(CONFIG) $(INCDIR)/version.h $(INCDIR)/tcb_layout.h $(INCDIR)/asmsyms.h $(KDB_HEADERS)

# Each object is written to its own directory. Compiler-generated .d files
# replace the old recursive preprocessing + Perl dependency pass.
$(OUT)/%.o: $(KERNEL)/%.cc $(GENERATED_HEADERS)
	@mkdir -p $(@D)
	$(CXX) $(PPFLAGS) -include $(KERNEL)/src/generic/types.h $(CXXFLAGS) \
	 -MMD -MP -MF $(@:.o=.d) -c $< -o $@
$(OUT)/%.o: $(KERNEL)/%.c $(GENERATED_HEADERS)
	@mkdir -p $(@D)
	$(CC) $(PPFLAGS) -include $(KERNEL)/src/generic/types.h $(CFLAGS) \
	 -MMD -MP -MF $(@:.o=.d) -c $< -o $@
$(OUT)/%.o: $(KERNEL)/%.S $(GENERATED_HEADERS)
	@mkdir -p $(@D)
	$(CC) -DASSEMBLY $(PPFLAGS) $(ASFLAGS) -MMD -MP -MF $(@:.o=.d) -c $< -o $@

# Historical bootstrap object is 32-bit instructions embedded in a 64-bit ELF.
ifeq ($(SUBARCH),x64)
$(OUT)/src/arch/x86/x64/init32.o: $(KERNEL)/src/arch/x86/x64/init32.cc $(GENERATED_HEADERS)
	@mkdir -p $(@D)
	$(CXX) $(PPFLAGS) -include $(KERNEL)/src/generic/types.h \
	 $(filter-out -m64 -mcmodel=kernel,$(CXXFLAGS)) -m32 -DX64_32BIT_CODE \
	 -MMD -MP -MF $(@:.o=.d) -c $< -o $@
	$(OBJCOPY) -g -O elf64-x86-64 $@ $@.converted
	@mv $@.converted $@
endif

LDSCRIPT := $(KERNEL)/src/glue/v4-x86/$(SUBARCH)/linker.lds
$(OUT)/linker.lds: $(LDSCRIPT) $(CONFIG) $(KERNEL)/src/generic/macros.h \
 $(wildcard $(KERNEL)/src/generic/*.ldi) \
 $(wildcard $(KERNEL)/src/api/v4/*.ldi)
	@mkdir -p $(@D)
	$(CXX) -E -x c -DASSEMBLY $(PPFLAGS) -P -C $< -o $@
$(KERNEL_ELF): $(OBJS) $(OUT)/linker.lds
	$(LD) $(LDFLAGS_$(SUBARCH)) -static -T $(OUT)/linker.lds -o $@ $(OBJS) $(if $(filter x64,$(SUBARCH)),-L$(dir $(shell $(CXX) -print-libgcc-file-name)) -lgcc,)
	@printf 'Kernel image: %s\n' '$@'

clean distclean:
	@rm -rf -- '$(OUT)'


# --- Freestanding L4 userland and QEMU/GRUB boot tools ---------------------
# This is an intentionally separate GNU Make workflow: the kernel's x86-64
# profile does not accidentally compile 32-bit bootstrap objects as ELF64.
USER_BUILD := $(ROOT)/build/user-amd64
BOOT_DIR := $(ROOT)/build/boot/$(PROFILE)
BOOT_ROOT_TASK ?= pingpong
.PHONY: userland l4test bootfiles bootcheck qemu-iso qemu qemu-gdb
userland:
	$(MAKE) -f $(ROOT)/user/Makefile.modern OUT=$(USER_BUILD) all
l4test:
	$(MAKE) -f $(ROOT)/user/Makefile.modern OUT=$(USER_BUILD) l4test
bootfiles: $(KERNEL_ELF) userland $(if $(filter l4test,$(BOOT_ROOT_TASK)),l4test)
	@case '$(SUBARCH)' in x64) ;; *) echo 'Boot bundle currently supports x86-64 only' >&2; exit 1;; esac
	@case '$(BOOT_ROOT_TASK)' in pingpong|l4test) ;; *) echo 'BOOT_ROOT_TASK must be pingpong or l4test' >&2; exit 1;; esac
	@mkdir -p $(BOOT_DIR)
	@cp $(USER_BUILD)/util/kickstart/kickstart $(BOOT_DIR)/kickstart
	@cp $(KERNEL_ELF) $(BOOT_DIR)/x86-kernel
	@cp $(USER_BUILD)/serv/sigma0/sigma0 $(BOOT_DIR)/sigma0
	@cp $(USER_BUILD)/apps/$(if $(filter l4test,$(BOOT_ROOT_TASK)),l4test/l4test,bench/pingpong/pingpong) $(BOOT_DIR)/roottask
	@printf '%s\n' 'Staged Multiboot images in $(BOOT_DIR)'
bootcheck: bootfiles
	@$(ROOT)/scripts/check-bootfiles.sh $(BOOT_DIR)
qemu-iso: bootcheck
	@$(ROOT)/scripts/make-iso.sh $(BOOT_DIR)/kickstart $(BOOT_DIR)/x86-kernel \
	 $(BOOT_DIR)/sigma0 $(BOOT_DIR)/roottask $(BOOT_DIR)/pistachio.iso
qemu: qemu-iso
	@$(ROOT)/scripts/run-qemu.sh $(BOOT_DIR)/pistachio.iso
qemu-gdb: qemu-iso
	@$(ROOT)/scripts/run-qemu.sh $(BOOT_DIR)/pistachio.iso --gdb

# No deps during initial parse or cleanup.
ifneq ($(filter clean distclean help profiles check-tools test userland l4test,$(MAKECMDGOALS)),)
else
-include $(DEPS)
endif
