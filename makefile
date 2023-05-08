CC = $(CROSS_COMPILE)gcc
DEFINES = -D_GNU_SOURCE
INCLUDES = -I/usr/include/libmongoc-1.0 -I/usr/include/libbson-1.0
CFLAGS = -g -O2 -Wall -Werror $(DEFINES) $(INCLUDES)
YACC := bison
LEX  := flex

# dpkg-parsechangelog is significantly slow
CHANGELOG = $(shell head -n 1 ./debian/changelog)
VER_STR = $(shell echo "$(CHANGELOG)" | sed -n -e 's/.*(\(.*[0-9]\+\.[0-9]\+\.[0-9]\+.*\)).*/\1/p')
VER = $(shell echo "$(VER_STR)" | sed -n -e 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
MAJ = $(shell echo "$(VER)" | cut -d . -f 1)
MIN = $(shell echo "$(VER)" | cut -d . -f 2)
REV = $(shell echo "$(VER)" | cut -d . -f 3)

ARCH = $(shell dpkg --print-architecture)

SRCS := $(wildcard *.c)
DEPS := $(SRCS:.c=.d)
BINS := decharged dechargebmsd dechargepsu dechargehttpd dechargeuartd decharge-cli

ifeq ($(ARCH), amd64)
  # Build dechargebroker only on x86-64
  BINS += dechargebroker
endif

LIBDECHARGE-SRCS := libdecharge.o libdecharge-local.o libdecharge-remote.o \
		     libdecharge-dummy.o libdechargebms.o libdechargedp.o bms-btle.o \
		     libdechargepsu.o libi2c/i2c.o gpio.o
LIBDECHARGE-LIBS := -lpthread -lserialport -lczmq -lzmq -luuid -lgps -lz

ifeq ("$(origin V)", "command line")
  VERBOSE = $(V)
endif
ifndef VERBOSE
  VERBOSE = 0
endif

ifeq ($(VERBOSE),1)
  Q =
else
  Q = @
endif

all: $(BINS)

##
## docopt-gen
##

docopt-gen:
ifneq ($(VERBOSE),1)
	@echo " LD $@"
endif
	$(Q)$(MAKE) -C docopt
	$(Q)cp docopt/docopt docopt-gen
	$(Q)$(MAKE) -C docopt clean

##
## version.h
##

version.h: debian/changelog
ifneq ($(VERBOSE),1)
	@echo " GEN $@"
endif
	@printf "/* File is automatically generated */\n" >  version.h
	@printf "#ifndef VERSION_H\n"                     >> version.h
	@printf "#define VERSION_H\n\n"                   >> version.h
	@printf "#define DECHARGE_VERSION     0x%08x\n" \
		$$(($(MAJ) << 16 | $(MIN) << 8 | $(REV))) >> version.h
	@printf "#define DECHARGE_VERSION_STR \"%s\"\n\n" $(VER_STR) \
							  >> version.h
	@printf "#endif /* VERSION_H */\n"                >> version.h


%-cmd.h %-cmd.y %-cmd.l: | docopt-gen %-cmd.docopt
ifneq ($(VERBOSE),1)
	@echo " GEN $@"
endif
	$(Q)$(RM) $*-cmd.h $*-cmd.l $*-cmd.y
	$(Q)./docopt-gen $*-cmd.docopt

%-cmd.tab.c: %-cmd.y
ifneq ($(VERBOSE),1)
	@echo "YACC $@"
endif
	$(Q)$(YACC) -o $@ --defines $*-cmd.y

%-cmd.lex.c: %-cmd.l %-cmd.tab.c
ifneq ($(VERBOSE),1)
	@echo " LEX $@"
endif
	$(Q)$(LEX) -o $@ $*-cmd.l

# Generate automatic prerequisites, i.e. dependencies
# http://make.mad-scientist.net/papers/advanced-auto-dependency-generation/
%.o : %.c
	@$(MAKEDEPEND)
ifneq ($(VERBOSE),1)
	@echo "  CC $@"
endif
	$(Q)$(COMPILE.c) -o $@ $<

ifneq ($(MAKECMDGOALS),clean)
-include $(DEPS)
endif

##
## dechargehttpd
##
dechargehttpd.o: dechargehttpd-cmd.h version.dechargehttpd: dechargehttpd.o $(LIBDECHARGE-SRCS) \
	  dechargehttpd-cmd.tab.o dechargehttpd-cmd.lex.o
ifneq ($(VERBOSE),1)
	@echo "  LD $@"
endif
	$(Q)$(CC) $(LFLAGS) -o $@ $^ -lmicrohttpd $(LIBDECHARGE-LIBS)

##
## dechargeuartd
##
dechargeuartd.o: dechargeuartd-cmd.h version.h

dechargeuartd: dechargeuartd.o $(LIBDECHARGE-SRCS) \
	  dechargeuartd-cmd.tab.o dechargeuartd-cmd.lex.o
ifneq ($(VERBOSE),1)
	@echo "  LD $@"
endif
	$(Q)$(CC) $(LFLAGS) -o $@ $^ $(LIBDECHARGE-LIBS)

##
## dechargebroker
##
dechargebroker.o: dechargebroker-cmd.h version.h

dechargebroker: dechargebroker.o dechargebroker-cmd.tab.o dechargebroker-cmd.lex.o libdecharge.o
ifneq ($(VERBOSE),1)
	@echo "  LD $@"
endif
	$(Q)$(CC) $(LFLAGS) -o $@ $^ -lczmq -lzmq -luuid -lmongoc-1.0 -lbson-1.0 -lpthread

##
## dechargeserver (decharged)
##
dechargeserver.o: dechargeserver-cmd.h version.h

decharged: dechargeserver.o avahi.o $(LIBDECHARGE-SRCS) \
	   dechargeserver-cmd.tab.o dechargeserver-cmd.lex.o
ifneq ($(VERBOSE),1)
	@echo "  LD $@"
endif
	$(Q)$(CC) $(LFLAGS) -o $@ $^ $(LIBDECHARGE-LIBS) -lavahi-client -lavahi-common -lsystemd

##
## dechargebmsd (decharged)
##
dechargebms.o: dechargebms-cmd.h version.h

dechargebmsd: dechargebms.o libdechargebms.o bms-btle.o dechargebms-cmd.tab.o dechargebms-cmd.lex.o
ifneq ($(VERBOSE),1)
	@echo "  LD $@"
endif
	$(Q)$(CC) $(LFLAGS) -o $@ $^ -lserialport

##
## dechargepsu (decharged)
##
dechargepsu.o: libdechargepsu.h

dechargepsu: dechargepsu.o libsdeschargeCC = $(CROSS_COMPILE)gcc
DEFINES = -D_GNU_SOURCE
INCLUDES = -I/usr/include/libmongoc-1.0 -I/usr/include/libbson-1.0
CFLAGS = -g -O2 -Wall -Werror $(DEFINES) $(INCLUDES)
YACC := bison
LEX  := flex

# dpkg-parsechangelog is significantly slow
CHANGELOG = $(shell head -n 1 ./debian/changelog)
VER_STR = $(shell echo "$(CHANGELOG)" | sed -n -e 's/.*(\(.*[0-9]\+\.[0-9]\+\.[0-9]\+.*\)).*/\1/p')
VER = $(shell echo "$(VER_STR)" | sed -n -e 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
MAJ = $(shell echo "$(VER)" | cut -d . -f 1)
MIN = $(shell echo "$(VER)" | cut -d . -f 2)
REV = $(shell echo "$(VER)" | cut -d . -f 3)

ARCH = $(shell dpkg --print-architecture)

S
