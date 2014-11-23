# EDIT RULES/TARGETS IN `rules.mk` INSTEAD OF THIS FILE.

# This file contains logic to cause the build to happen in a separate
# directory.

# Test that the current directory name doesn't start with `_`.
#ifeq (,$(filter _%,$(notdir $(CURDIR))))
# Test that the current directory name isn't `build`.
ifeq (,$(filter build,$(notdir $(CURDIR))))

## Part 1 - To be run for the instance in the project dir
# Based on
# http://make.mad-scientist.net/papers/multi-architecture-builds/

# Clear all(ish) built-in rules.
.SUFFIXES:

# Set where all the products go.
# (This could include some logic if desired.)
#OBJDIR := _build
OBJDIR := build

# Stash the entire *actual* make command, to be run from inside the build
# dir.
MAKETARGET = $(MAKE) \
	--no-print-directory \
	-C $@ \
	-f $(CURDIR)/Makefile \
	SRCDIR=$(CURDIR) \
	$(MAKECMDGOALS)

# Relocate to the build dir and run the sub-make, ensuring the directory
# exists first.
# (The `+` prefix makes a command run even under `-n`. `@` suppresses echo
# to hide the noise from the jump.)
.PHONY: $(OBJDIR)
$(OBJDIR):
	+@[ -d $@ ] || mkdir -p $@
	+@$(MAKETARGET)

# Prevent make from attempting to rebuild the makefiles infinitely.
Makefile : ;
%.mk :: ;

# Catch-all rule to pass make targets to the $(OBJDIR) rule.
# (`:` is a sh-style no-op, here to suppress spurious "nothing to do"
# errors.)
% :: $(OBJDIR) ; :

# The clean rule simply destroys the build dir, which might be the most
# pressing reason to put build products in a single directory (versus giving
# a laundry list of individual files and patterns to delete).
.PHONY: clean
clean:
	rm -rf $(OBJDIR)

## End Part 1

else

## Part 2 - To be run for the instance in the build dir
VPATH = $(SRCDIR)
include $(SRCDIR)/rules.mk
## End Part 2

endif

