use Zarr;
use IO;
use FileSystem;
proc smallTest(type dtype) {
  {
    const N1 = 100;
    const D1 = {0..<N1};
    var A1: [D1] dtype;
    for i in D1 do A1[i] = (i + 3):dtype;
    if (exists("Test1D")) then rmTree("Test1D");
    writeZarrArray("Test1D", A1, (7,));

    var B1 = readZarrArray("Test1D", dtype, 1);
    
    assert(A1.domain == B1.domain, "Domain mismatch: %? %?".format(A1.domain, B1.domain));
    forall i in A1.domain do 
      assert(A1[i] == B1[i], "Mismatch for 1D real data on indices: %?.\nWritten: %?\nRead: %?".format(i, A1[i], B1[i]));
    writeln("Success for 1D.");
    rmTree("Test1D");
  }

  {
    const N2 = 100;
    const D2 = {0..<N2,0..<N2};
    var A2: [D2] dtype;
    for (i,j) in D2 do A2[i,j] = (i:real(32) / (j+1)) : dtype;
    if (exists("Test2D")) then rmTree("Test2D");
    writeZarrArray("Test2D", A2, (7,18));

    var B2 = readZarrArray("Test2D", dtype, 2);
    
    assert(A2.domain == B2.domain, "Domain mismatch: %? %?".format(A2.domain, B2.domain));
    forall i in A2.domain do 
      assert(A2[i] == B2[i], "Mismatch for 2D real data on indices: %?.\nWritten: %?\nRead: %?".format(i, A2[i], B2[i]));
    writeln("Success for 2D.");
    rmTree("Test2D");
  }

  {
    const N3 = 30;
    const D3 = {0..<N3,0..<N3,0..<N3};
    var A3: [D3] dtype;
    for (i,j,k) in D3 do A3[i,j,k] = (i:real(32) / ((j+1) + (k+1))) : dtype;
    if (exists("Test3D")) then rmTree("Test3D");
    writeZarrArray("Test3D", A3, (7,18,22));

    var B3 = readZarrArray("Test3D", dtype, 3);
    
    assert(A3.domain == B3.domain, "Domain mismatch: %? %?".format(A3.domain, B3.domain));
    forall i in A3.domain do 
      assert(A3[i] == B3[i], "Mismatch for 3D real data on indices: %?.\nWritten: %?\nRead: %?".format(i, A3[i], B3[i]));
    writeln("Success for 3D.");
    rmTree("Test3D");
  }
}


proc main() {
  smallTest(int(32));
  smallTest(int(64));
  smallTest(real(32));
  smallTest(real(64));
}