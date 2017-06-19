#!/bin/tcsh
#
# Purpose
# -------
# 1. Builds and installs PISM version 0.7.2 on the UNSW Faculty of Science
#    cluster katana.science.unsw.edu.au.
#
# 2. Generates scripts to run the two quick tests described in the PISM
#    Installation manual.
#
# Usage
# -----
# 1. To compile and build PISM, enter the command:
#
#    ./build_pism_v0p7p2_katana
#
# 2. To run the first test, enter the commands:
#
#    cd ~/PISM/pism/bin
#    ./test1
#
# 3. To run the second test, enter the commands:
#
#    cd ~/PISM/pism/bin
#    ./test2
#
# Notes
# -----
# 1. By default, this script builds and installs PISM in the directory ~/PISM.
#    To build and install PISM in a different location, change the value of
#    PISM_ROOT_DIR in the User Interface section below.
#
# 2. This script only builds and install the PISM executables. Software such
#    as CDO and NCO, and python packages such as numpy, might also need to be
#    installed before pre- and post-processing scripts can be run.
#
# History
# -------
# 2015 Dec 14	Steven Phipps	Original version
# 2017 Jun 19	Helen Millman	Update


######################
#                    #
#   USER INTERFACE   #
#                    #
######################

# Build and install PISM in this directory
setenv PISM_ROOT_DIR ${HOME}/new_PISM


##############################
#                            #
#   BUILD AND INSTALL PISM   #
#                            #
##############################

### 1. USER ENVIRONMENT
###
### Set up the user environment.

# Check whether the root directory already exists. If it does exist, then abort
# so that we don't over-write any existing installation(s). If it doesn't
# exist, then create it.
if (-e $PISM_ROOT_DIR) then
  echo
  echo '*** ABORTING'
  echo '***'
  echo '***' $PISM_ROOT_DIR 'ALREADY EXISTS'
  echo
  exit
else
  mkdir $PISM_ROOT_DIR
endif

# Change to the root directory
cd $PISM_ROOT_DIR

# Unload all currently loaded modules. This is necessary so that we start with
# a completely clean environment and avoid any potential conflicts.
module purge

# Load the modules that we need to build and install PISM. In the interests of
# reproducibility, we specify the precise version of each module.
module load cmake/3.3.2
module load fftw/3.3.4
module load gsl/1.15
module load hdf5/1.8.15
module load netcdf/4.2.1
module load openmpi/1.8.3
module load petsc/3.5.3
module load proj4/4.8.0

# List the modules that are currently loaded. The same modules (with the
# exception of cmake) will need to be loaded when running PISM. The test
# scripts provide examples of this.
echo
module list
echo

### 2. LIBRARIES
###
### Compile and install any libraries that are required by PISM and which
### either (a) are not installed, or (b) are installed, but we cannot use the
### existing version(s) for some reason.

# UDUNITS-2: This library is installed on katana, but we need to compile a
# version with the -fPIC option to gcc. Note that there is a "make check" stage
# to the compilation process for UDUNITS-2, but it does not perform any actual
# tests and so we skip it.
echo
echo '*** GETTING SOURCE CODE FOR UDUNITS-2 VERSION 2.2.24 ...'
echo
wget ftp://ftp.unidata.ucar.edu/pub/udunits//udunits-2.2.24.tar.gz
tar zxvf udunits-2.2.24.tar.gz
/bin/rm udunits-2.2.24.tar.gz

echo
echo '*** COMPILING AND INSTALLING UDUNITS-2 ...'
echo
cd udunits-2.2.24
./configure --prefix=$PISM_ROOT_DIR --with-pic
make
make install
make distclean
cd ..

# PnetCDF: This library is not installed on katana. Note that we skip the
# optional "make testing" and "make ptest" stages of the compilation process.
# This is potentially a little dangerous, as it assumes that the library has
# compiled correctly.
echo
echo '*** GETTING SOURCE CODE FOR PnetCDF VERSION 1.6.1 ...'
echo
wget http://cucis.ece.northwestern.edu/projects/PnetCDF/Release/parallel-netcdf-1.6.1.tar.gz
tar zxvf parallel-netcdf-1.6.1.tar.gz
/bin/rm parallel-netcdf-1.6.1.tar.gz

echo
echo '*** COMPILING AND INSTALLING PnetCDF ...'
echo
cd parallel-netcdf-1.6.1
./configure --prefix=$PISM_ROOT_DIR --with-mpi=/export/apps/openmpi/1.8.3
make
make install
make distclean
cd ..

### 3. PISM
###
### Build and install PISM.

# Get the source code for version 0.7.2.
echo
echo '*** GETTING SOURCE CODE FOR PISM VERSION 0.7.2 ...'
echo
wget https://github.com/pism/pism/archive/v0.7.2.tar.gz
tar zxvf v0.7.2
/bin/rm v0.7.2

# Create the build directory
mkdir pism-0.7.2/build

# Change to the build directory
cd pism-0.7.2/build

# Create a CMake script
set CMAKE_SCRIPT = pism_config.cmake
cat << EOF > $CMAKE_SCRIPT
# Compiler
set (CMAKE_C_COMPILER "mpicc" CACHE STRING "")
set (CMAKE_CXX_COMPILER "mpicxx" CACHE STRING "")

# Installation path
set (CMAKE_INSTALL_PREFIX "\$ENV{PISM_ROOT_DIR}/pism" CACHE STRING "")

# UDUNITS-2
set (UDUNITS2_LIBRARIES "\$ENV{PISM_ROOT_DIR}/lib/libudunits2.a" CACHE STRING "")
set (UDUNITS2_INCLUDES "\$ENV{PISM_ROOT_DIR}/include" CACHE STRING "")

# PnetCDF
set (PNETCDF_LIBRARIES "\$ENV{PISM_ROOT_DIR}/lib/libpnetcdf.a" CACHE STRING "")
set (PNETCDF_INCLUDES "\$ENV{PISM_ROOT_DIR}/include" CACHE STRING "")
EOF

# Build PISM
echo
echo '*** BUILDING AND INSTALLING PISM ...'
echo
cmake -C $CMAKE_SCRIPT ..
make install

### 4. TEST SCRIPTS
###
### Generate scripts to run the two quick tests described in the PISM
### Installation Manual.

# Test 1: Simple four-process verification run
set TEST1_SCRIPT = ${PISM_ROOT_DIR}/pism/bin/test1
cat << EOF > $TEST1_SCRIPT
#!/bin/tcsh

# Unload all currently loaded modules
module purge

# Load the modules that we need to run PISM
module load fftw/3.3.4
module load gsl/1.15
module load hdf5/1.8.15
module load netcdf/4.2.1
module load openmpi/1.8.3
module load petsc/3.5.3
module load proj4/4.8.0

# Delete the file unnamed.nc if it already exists
if (-e unnamed.nc) /bin/rm unnamed.nc

# Carry out a simple four-process verification run
mpiexec -n 4 ./pismv -test G -y 200
EOF
chmod u+x $TEST1_SCRIPT

# Test 2: EISMINT II run using the PETSc viewers
set TEST2_SCRIPT = ${PISM_ROOT_DIR}/pism/bin/test2
cat << EOF > $TEST2_SCRIPT
#!/bin/tcsh

# Unload all currently loaded modules
module purge

# Load the modules that we need to run PISM
module load fftw/3.3.4
module load gsl/1.15
module load hdf5/1.8.15
module load netcdf/4.2.1
module load openmpi/1.8.3
module load petsc/3.5.3
module load proj4/4.8.0

# Delete the file unnamed.nc if it already exists
if (-e unnamed.nc) /bin/rm unnamed.nc

# Carry out an EISMINT II run using the PETSc viewers
mpiexec -n 2 ./pisms -y 5000 -view_map thk,temppabase,velsurf_mag
EOF
chmod u+x $TEST2_SCRIPT

