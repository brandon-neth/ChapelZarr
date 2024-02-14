use IO;
use JSON;
use Map;
use List;
use Path;
use CTypes;
use BlockDist;
use Time;

require "blosc.h";
require "-lblosc";
extern proc blosc_init();
extern proc blosc_decompress(src: c_ptrConst(void), dest: c_ptr(void), destsize: c_size_t): int;
extern proc blosc_destroy();

// checks values based on how the data is written
proc verifyCorrectness(ref A: [?D]) {
  param dimCount = D.rank;
  if dimCount == 1 then
    forall i in A.domain do assert(A[i] == i);

  if dimCount == 2 {
    forall (i,j) in A.domain {
      if (A[i,j] != i*j) {
        writeln("Failure for indices %i %i".format(i,j));
        writeln("Expected: %i\nReceived: %s".format(i*j, A[i,j]:string));
        
        assert(A[i,j] == i*j);
      }
      
    }
  }
    
  if dimCount == 3 then
    forall (i,j,k) in A.domain do
      assert(A[i,j,k] == k + i*j);
}

record zarrMetadataV2 {
  var zarr_format: int;
  var chunks: list(int);
  var dtype: string;
  var shape: list(int);
};

record zarrMetadataV3 {
  var zarr_format: int;
  var node_type: string;
  var shape: list(int);
  var data_type: string;
  var dimension_names: list(string);
};

proc buildChunkPath(directoryPath: string, delimiter: string, const chunkIndices: ?dimCount * int) {
  var indexStrings: dimCount*string;
  for i in 0..<dimCount do indexStrings[i] = chunkIndices[i] : string;
  return joinPath(directoryPath, delimiter.join(indexStrings));
}

proc chunkIndexToLocalDomain(fullShape: ?dimCount * int, chunkShape: dimCount*int, chunkIndices: dimCount*int) {
  var ranges: dimCount*range(int);
  for i in 0..<chunkShape.size {
    var low = chunkShape[i] * chunkIndices[i];
    var high =  min(fullShape[i], chunkShape[i] * (chunkIndices[i] + 1));
    ranges[i] = low..<high;
  }
  var d : domain(dimCount) = ranges;
  return d;
}


proc readChunk(param dimCount: int, chunkPath: string, chunkDomain: domain(dimCount), ref arraySlice: [] ?t) {
  const f = open(chunkPath, ioMode.r);
  const r = f.reader(deserializer = new binaryDeserializer());
  var compressedChunk = r.readBytes(f.size);
  var copyIn: [chunkDomain] t;
  var numRead = blosc_decompress(compressedChunk.c_str(), c_ptrTo(copyIn), copyIn.size*c_sizeof(t));
  arraySlice[arraySlice.domain] = copyIn[arraySlice.domain];
  
}


proc readZarrArrayV2Dist(directoryPath: string, type dtype, param dimCount: int) {
  var metadataPath = joinPath(directoryPath, ".zarray");
  var r = openReader(metadataPath, deserializer = new jsonDeserializer());
  var md: zarrMetadataV2;
  r.readf("%?", md);
  var totalShape, chunkShape : dimCount*int;
  var chunkCounts: dimCount*int;
  var totalRanges,chunkRanges: dimCount*range(int);

  for i in 0..<dimCount {
    totalShape[i] = md.shape[i];
    chunkShape[i] = md.chunks[i];
    chunkCounts[i] = ceil(totalShape[i]:real / chunkShape[i]:real) : int;
    totalRanges[i] = 0..<totalShape[i];
    chunkRanges[i] = 0..<chunkCounts[i];
  }
  const fullChunkDomain: domain(dimCount) = chunkRanges;

  const undistD : domain(dimCount) = totalRanges;
  const Dist = new blockDist(boundingBox=undistD);
  const D = Dist.createDomain(undistD);
  var A: [D] dtype;

  coforall loc in Locales do on loc {
    blosc_init();

    const hereD = A.localSubdomain();
    ref hereA = A[hereD];

    var localChunks: dimCount*range(int);
    for i in 0..<dimCount {
      var low = floor(hereD.low[i]:real / chunkShape[i]:real):int;
      var high = min(chunkCounts[i],ceil((hereD.high[i]+1) / chunkShape[i]:real):int);

      localChunks[i] = low..<high; 
    }
    const localChunkDomain: domain(dimCount) = localChunks;

    forall chunkIndices in localChunkDomain do {
      
      const chunkPath = buildChunkPath(directoryPath, ".", chunkIndices);
      var thisChunkRange: dimCount*range(int);
      for i in 0..<dimCount {
        const start = chunkIndices[i] * chunkShape[i];
        thisChunkRange[i] = start..<start+chunkShape[i];
      }
      const thisChunkDomain: domain(dimCount) = thisChunkRange;
      const thisChunkHere = hereD[thisChunkDomain];
      
      ref thisChunkSlice = hereA.localSlice(thisChunkHere);
      readChunk(dimCount, chunkPath, thisChunkDomain, thisChunkSlice);
    }


    blosc_destroy();
  }

  return A;
}

proc readZarrArrayV2(directoryPath: string, type dtype, param dimCount: int) {
  var metadataPath = joinPath(directoryPath, ".zarray");
  var r = openReader(metadataPath, deserializer = new jsonDeserializer());
  var md: zarrMetadataV2;
  r.readf("%?", md);
  var totalShape, chunkShape : dimCount*int;
  var chunkCounts: dimCount*int;
  var totalRanges,chunkRanges: dimCount*range(int);

  for i in 0..<dimCount {
    totalShape[i] = md.shape[i];
    chunkShape[i] = md.chunks[i];
    chunkCounts[i] = ceil(totalShape[i]:real / chunkShape[i]:real) : int;
    totalRanges[i] = 0..<totalShape[i];
    chunkRanges[i] = 0..<chunkCounts[i];
  }

  
  const D: domain(dimCount) = totalRanges;
  var A: [D] dtype;

  const chunkDomain: domain(dimCount) = chunkRanges;
  blosc_init();
  forall chunkIndices in chunkDomain do {
    
    const chunkPath = buildChunkPath(directoryPath, ".", chunkIndices);
    
    var thisChunkRange: dimCount*range(int);
    for i in 0..<dimCount {
      const start = chunkIndices[i] * chunkShape[i];
      thisChunkRange[i] = start..<start+chunkShape[i];
    }
    const thisChunkDomain: domain(dimCount) = thisChunkRange;
    const thisChunkHere = D[thisChunkDomain];
    
    ref thisChunkSlice = A.localSlice(thisChunkHere);
    readChunk(dimCount, chunkPath, thisChunkDomain, thisChunkSlice);
  }
  blosc_destroy();
  return A;
}

proc throughputTest(param dimCount: int, type dtype) {
  var s: stopwatch;
  var gbs = 1;
  var name = "%igb%id%s%i".format(gbs, dimCount, (dtype:string).replace("(", "").replace(")",""));
  {
    writeln("Starting single-locale read of %iGB %iD store of %s".format(gbs, dimCount, dtype:string));
    s.restart();
    var A = readZarrArrayV2(name, dtype, dimCount);
    var t = s.elapsed();
    verifyCorrectness(A);
    writeln("Throughput: ", gbs:real / t, " GB/s on ", 1, " locale");
    
  }
  writeln();
  {
    writeln("Starting distributed read of %iGB %iD store of %s".format(gbs, dimCount, dtype:string));
    s.restart();
    var A = readZarrArrayV2Dist(name, dtype, dimCount);
    var t = s.elapsed();
    verifyCorrectness(A);
    writeln("Throughput: ", gbs:real / t, " GB/s on ", numLocales, " locales");
  }
  writeln();
}

proc smallTestReal() {
  writeln("Single-locale read...");
  var A = readZarrArrayV2("1mb2dreal32", real(32), 2);
  verifyCorrectness(A);

  writeln("Distributed read...");
  var A2 = readZarrArrayV2Dist("1mb2dreal32", real(32), 2);
  verifyCorrectness(A2);
}

proc smallTestInt() {
  writeln("Single-locale read...");
  var A = readZarrArrayV2("1mb2dint32", int(32), 2);
  verifyCorrectness(A);

  writeln("Distributed read...");
  var A2 = readZarrArrayV2Dist("1mb2dint32", int(32), 2);
  verifyCorrectness(A2);
}

//smallTestInt();
writeln("Chunk Size: 10MB");
throughputTest(2, real(32));
throughputTest(2, int(32));
throughputTest(2, int(64));
