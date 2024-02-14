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
  z[:] = np.arange(shape[0])
elif dimensionality==2:
  for i in range(total_side):
    z[i,:] = np.arange(shape[1]) * i
elif dimensionality==3:
  for i in range(total_side):
    for j in range(total_side):
      z[i,j,:] = np.arange(shape[2]) + i * j
