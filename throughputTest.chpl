use IO;
use Time;
use Zarr;


config param dimCount = 2;
config type dtype = real(32);

config const storePath: string;

var s: stopwatch;
s.start();
var A = readZarrArray(storePath, dtype, dimCount);
s.stop();

var numElts = A.size;
var numBytes: real = numElts * numBits(dtype) / 8;
var numGiBs: real = numBytes / (1024 ** 3);

var throughput: real = numGiBs / s.elapsed();

writeln("Throughput: %n GiB/s on %n locales".format(throughput, numLocales));
