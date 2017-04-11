#!/bin/bash
#
# script to build HermitCore's bootstrap compiler
#
# $1 = specifies the target architecture
# $2 = specifies the installation directory

BUILDDIR=build
CLONE_DEPTH="--depth=50"
PREFIX="$2"
TARGET=$1
NJOBS=-j"$(nproc)"
PATH=$PATH:$PREFIX/bin

echo "Build bootstrap toolchain for $TARGET with $NJOBS jobs for $PREFIX"
sleep 1

mkdir -p $BUILDDIR
cd $BUILDDIR

if [ ! -d "binutils" ]; then
git clone $CLONE_DEPTH https://github.com/RWTH-OS/binutils.git
fi

if [ ! -d "gcc" ]; then
git clone $CLONE_DEPTH https://github.com/RWTH-OS/gcc.git
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.15.tar.bz2 -O isl-0.15.tar.bz2
tar jxf isl-0.15.tar.bz2
mv isl-0.15 gcc/isl
fi

if [ ! -d "hermit" ]; then
git clone --recursive -b devel https://github.com/RWTH-OS/HermitCore.git hermit
fi

if [ ! -d "newlib" ]; then
git clone $CLONE_DEPTH https://github.com/RWTH-OS/newlib.git
fi

if [ ! -d "pte" ]; then
git clone $CLONE_DEPTH https://github.com/RWTH-OS/pthread-embedded.git pte
cd pte
./configure --prefix=$PREFIX
fi

if [ ! -d "tmp/binutils" ]; then
mkdir -p tmp/binutils
cd tmp/binutils
../../binutils/configure --target=$TARGET --prefix=$PREFIX --with-sysroot --disable-multilib --disable-shared --disable-nls --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-libssp --enable-tls --enable-lto --enable-plugin && make $NJOBS && make install
cd -
fi

if [ ! -d "tmp/bootstrap" ]; then
mkdir -p tmp/bootstrap
cd tmp/bootstrap
../../gcc/configure --target=$TARGET --prefix=$PREFIX --without-headers --disable-multilib --with-isl --enable-languages=c,c++,lto --disable-nls --disable-shared --disable-libssp --disable-libgomp --enable-threads=posix --enable-tls --enable-lto --disable-symvers && make $NJOBS all-gcc && make install-gcc
cd -
fi

if [ ! -d "tmp/hermit" ]; then
mkdir -p tmp/hermit
cd tmp/hermit
cmake -DTOOLCHAIN_BIN_DIR=$PREFIX/bin -DCMAKE_INSTALL_PREFIX=$PREFIX -DBOOTSTRAP=true ../../hermit
make hermit-bootstrap
make hermit-bootstrap-install
cd -
fi

if [ ! -d "tmp/newlib" ]; then
mkdir -p tmp/newlib
cd tmp/newlib
../../newlib/configure --target=$TARGET --prefix=$PREFIX --disable-shared --disable-multilib --enable-lto --enable-newlib-hw-fp --enable-newlib-io-c99-formats --enable-newlib-multithread && make $NJOBS && make install
cd -
fi

cd pte
make && make install
cd ..

if [ ! -d "tmp/gcc" ]; then
mkdir -p tmp/gcc
cd tmp/gcc
../../gcc/configure --target=$TARGET --prefix=$PREFIX --with-newlib --with-isl --disable-multilib --without-libatomic --enable-languages=c,c++,go,fortran,lto --disable-nls --disable-shared --disable-libssp --enable-threads=posix --disable-libgomp --enable-tls --enable-lto --disable-symver && make $NJOBS && make install
cd -
fi

if [ ! -d "tmp/final" ]; then
mkdir -p tmp/final
cd tmp/final
cmake -DTOOLCHAIN_BIN_DIR=$PREFIX/bin -DCMAKE_INSTALL_PREFIX=$PREFIX ../../hermit
make libiomp
cp local_prefix/work/hermit/$TARGET/lib/libgomp.spec $PREFIX/$TARGET/lib
cp local_prefix/work/hermit/$TARGET/lib/*.a $PREFIX/$TARGET/lib
cp local_prefix/work/hermit/$TARGET/include/*.h $PREFIX/$TARGET/include
make
make install
cd -
fi

cd ..
