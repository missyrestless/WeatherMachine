# Configuration area

# Full path to Python. For Windows this is typically
# C:\Python27\python.exe; if it is in your path you don't need to change it.
PYTHON=python3

# Full path to main.py in the optimizer. Depends on where it was unpacked.
OPTIMIZER=/opt/pyoptimizer/main.py

# Which preprocessor to use. Use 'gcpp' for GNU cpp (typical on Linux/OSX);
# use 'mcpp' for mcpp.
PREPROC_KIND=gcpp

# Full path to the preprocessor. Depends on where you have downloaded it.
# If the preprocessor is GNU cpp and it is in your path, leave it as cpp.
PREPROC_PATH=cpp

# End of configuration area

# Version being compiled (LSL string)
VERSION="1.1.0"


# Note some of these scripts don't strictly need to be optimized for memory.

OPTIMIZED=Controller.lslo Emitter.lslo

UNOPTIMIZED=

all: $(OPTIMIZED)
	$(PYTHON) build-aux.py rm $@

clean:
	$(PYTHON) build-aux.py rm $(OPTIMIZED)

optimized: $(OPTIMIZED)

%.lslo %.lslt: %.lsl
	$(PYTHON) $(OPTIMIZER) -H -O addstrings,shrinknames,-extendedglobalexpr -p $(PREPROC_KIND) --precmd=$(PREPROC_PATH) $(OFLAGS) $< -o $@

# Bash only, probably GNU make only
setvars:
	for name in $(addprefix ',$(addsuffix ',$(OPTIMIZED:.lslo=.lsl))) $(addprefix ',$(addsuffix ',$(UNOPTIMIZED))); do $(PYTHON) build-aux.py setvars "$$name" version='$(VERSION)' ; done

release: setvars all

test: all clean

.PHONY : all clean optimized setvars release
