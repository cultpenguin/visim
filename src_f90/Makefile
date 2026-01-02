#-----------------------------------------------------------------------
# VISIM F90 Makefile
# ------------------
# Builds the Fortran 90 version of VISIM with dynamic memory allocation
#-----------------------------------------------------------------------

# Compiler and flags
COMP = gfortran
FFLAGS = -O3 -Wall -fallow-argument-mismatch -fcheck=bounds

# Program name
PROG = visim_f90

# GSLIB library path (relative to src_f90/)
GSLIB_DIR = ../src/gslib
LIBGS = ../src/libgs.a

# Source files (order matters for dependencies!)

# 1. Modules (must be compiled first)
MOD_SRC = visim_modules.f90

# 2. Helper modules (depend on base modules)
HELPER_SRC = visim_allocate.f90 visim_readpar_populate.f90 visim_readpar_v2.f90

# 3. Converted subroutines
SUB_SRC = visim_srchnd.f90 visim_krige.f90 visim_simu.f90 visim_nhoodvol.f90 visim_ctable.f90 \
          visim_krige_volume.f90 visim_cov_data2vol.f90 visim_cov_vol2vol.f90 visim_cov_data2data.f90 \
          visim_randpath.f90 visim_setup_krgvar.f90 visim_trans.f90 visim_condtab.f90 visim_visim.f90

# 4. Main program
MAIN_SRC = visim_main.f90

# Object files
MOD_OBJ = $(MOD_SRC:.f90=.o)
HELPER_OBJ = $(HELPER_SRC:.f90=.o)
SUB_OBJ = $(SUB_SRC:.f90=.o)
MAIN_OBJ = $(MAIN_SRC:.f90=.o)

ALL_OBJ = $(MOD_OBJ) $(HELPER_OBJ) $(SUB_OBJ) $(MAIN_OBJ)

#-----------------------------------------------------------------------
# Build targets
#-----------------------------------------------------------------------

.PHONY: all clean test

all: $(PROG)

# Link program
$(PROG): $(ALL_OBJ) $(LIBGS)
	@echo "Linking $(PROG)..."
	$(COMP) $(FFLAGS) -o $@ $(ALL_OBJ) $(LIBGS)
	@echo "Build successful! Executable: $(PROG)"

# Build GSLIB library if needed
$(LIBGS):
	@echo "Building GSLIB library..."
	cd $(GSLIB_DIR) && $(MAKE)

# Compile modules first (they create .mod files needed by others)
$(MOD_OBJ): $(MOD_SRC)
	@echo "Compiling base modules..."
	$(COMP) $(FFLAGS) -c $(MOD_SRC)

# Compile helpers (depend on modules)
$(HELPER_OBJ): $(HELPER_SRC) $(MOD_OBJ)
	@echo "Compiling helper modules..."
	$(COMP) $(FFLAGS) -c $(HELPER_SRC)

# Compile subroutines (depend on modules)
$(SUB_OBJ): $(SUB_SRC) $(MOD_OBJ)
	@echo "Compiling converted subroutines..."
	$(COMP) $(FFLAGS) -c $(SUB_SRC)

# Compile main program (depends on all modules)
$(MAIN_OBJ): $(MAIN_SRC) $(MOD_OBJ) $(HELPER_OBJ) $(SUB_OBJ)
	@echo "Compiling main program..."
	$(COMP) $(FFLAGS) -c $(MAIN_SRC)

#-----------------------------------------------------------------------
# Test compilation only (no linking)
#-----------------------------------------------------------------------
test:
	@echo "Testing compilation..."
	$(COMP) $(FFLAGS) -c $(MOD_SRC)
	$(COMP) $(FFLAGS) -c $(HELPER_SRC)
	$(COMP) $(FFLAGS) -c $(SUB_SRC)
	$(COMP) $(FFLAGS) -c $(MAIN_SRC)
	@echo "All files compiled successfully!"

#-----------------------------------------------------------------------
# Clean build artifacts
#-----------------------------------------------------------------------
clean:
	@echo "Cleaning build artifacts..."
	rm -f *.o *.mod $(PROG)
	@echo "Clean complete."

clean-all: clean
	@echo "Cleaning GSLIB library..."
	cd $(GSLIB_DIR) && $(MAKE) clean
	@echo "Full clean complete."

#-----------------------------------------------------------------------
# Help
#-----------------------------------------------------------------------
help:
	@echo "VISIM F90 Makefile"
	@echo "=================="
	@echo "Targets:"
	@echo "  make          - Build visim_f90 executable"
	@echo "  make test     - Test compilation without linking"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make clean-all- Clean everything including GSLIB"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - gfortran compiler"
	@echo "  - GSLIB library in ../src/gslib/"
