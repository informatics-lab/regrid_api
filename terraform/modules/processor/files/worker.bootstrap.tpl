#!/bin/bash
export PATH="/home/ubuntu/anaconda3/bin:$PATH"
conda install -c conda-forge dask=${dask_ver} distributed=${distributed_ver} iris=${iris_ver} boto3 -y


echo "Waiting load balancer..."

while ! nc -w 2 -z ${scheduler_address} ${scheduler_port}; do   
  echo "waiting..."
  sleep 1 # wait for 1 second before check again
done

echo "load balancer up"


dask-worker ${scheduler_address}:${scheduler_port} --nprocs $(grep -c ^processor /proc/cpuinfo) --nthreads 1 