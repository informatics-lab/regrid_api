#!/bin/bash
apt-get update -y
apt-get upgrade -y
apt-get install bzip2 -y
wget http://repo.continuum.io/miniconda/Miniconda3-3.7.0-Linux-x86_64.sh -O ~/miniconda.sh
bash ~/miniconda.sh -b -p $HOME/miniconda
export PATH="$HOME/miniconda/bin:$PATH"
conda install dask distributed # TODO: specify versions.
dask-worker ${scheduler_address}