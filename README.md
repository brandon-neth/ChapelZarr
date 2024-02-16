This directory contains a prototype implementation of a reader for v2.0 zarr arrays.
It also includes a Chapel file that runs a throughput evaluation for a given zarr array.

## Step 1: Build Blosc

The implementation uses Blosc to decompress the array chunks and links against the `c-blosc` library. The following commands, run from this directory, should do the trick:

```
git clone https://github.com/Blosc/c-blosc.git
cd c-blosc
mkdir build
cd build
cmake ..
make -j4
cd ../..
```

You can optionally install the package, but this guide links against the copy in the build location.
Make sure your library path includes the path to the built libraries:
```
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)/c-blosc/build/blosc
```


## Step 2: Build Throughput Test

Once `c-blosc` is built, you can build the executable for the throughput test. 
The test executable must know the number of dimensions of the dataset and the data type. 
These are provided as arguments during compilation. 
The config names are `dimCount` and `dtype`, with default values of `2` and `real(32)`.
To test a 3D dataset of double precision floats, you would use the compiler flags `-sdimCount=3 -sdtype='real(64)'`. Note the single quotes around the type name.

The compilation command also needs to include the paths for the compiler to link against `c-blosc`. 
Because we built it here, those flags are `-I./c-blosc/blosc -L./c-blosc/build/blosc`.

So, to compile a 2D dataset of 32-bit integers, the compilation command is:
```
chpl -I./c-blosc/blosc -L./c-blosc/build/blosc -sdtype='int(32)' -sdimCount=2 throughputTest.chpl
```

This should produce an executable called `throughputTest`.

## Step 3: Run Throughput Test

Finally, you can run the throughput test. 
The executable is run with the config variable `storePath`. 
So to run the test across 4 locales on a store named `myStore` in the parent directory, you would run `./throughputTest -nl 4 --storePath ../myStore`.
