import zarr
import numpy as np
from hfilesize import FileSize
import sys
import math

chunk_size = 64

if len(sys.argv) != 6:
  print("ERROR: Please provide store name, dimensionality, total size, chunk size, and dtype")
  exit()
name = sys.argv[1]
dimensionality = int(sys.argv[2])
total_size = FileSize(sys.argv[3])
chunk_size = FileSize(sys.argv[4])
dtype = sys.argv[5]

bytes_per_elt = int(dtype[1:])

total_elts = math.ceil(total_size / bytes_per_elt)
chunk_elts = math.ceil(chunk_size / bytes_per_elt)

total_side = math.ceil(pow(total_elts, 1 / dimensionality))
chunk_side = math.ceil(pow(chunk_elts, 1 / dimensionality))

shape = tuple([total_side for _ in range(dimensionality)])
chunks = tuple([chunk_side for _ in range(dimensionality)])

z = zarr.open(name, mode='w', shape=shape, chunks=chunks, dtype=dtype)
if dimensionality==1:
  for i in range(0,shape[0], chunks[0]):
    z[i] = i
  
elif dimensionality==2:
  for i in range(0,shape[0], chunks[0]):
    for j in range(0,shape[1], chunks[1]):
      z[i,j] = i * j
elif dimensionality==3:
  for i in range(0,shape[0], chunks[0]):
    for j in range(0,shape[1], chunks[1]):
      for k in range(0,shape[2], chunks[2]):
        z[i,j,k] = i * j + k
