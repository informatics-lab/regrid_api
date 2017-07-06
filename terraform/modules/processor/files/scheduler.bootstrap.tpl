#!/bin/bash
export QUEUE_NAME=${input_queue_name}
export PATH="/home/ubuntu/anaconda3/bin:$PATH"
conda install  -c conda-forge  dask=${dask_ver} distributed=${distributed_ver}  iris=${iris_ver} boto3 -y   
dask-scheduler --port 8786 --bokeh-port 8787 &
cat <<EOT >> process.py
${script}
EOT
/home/ubuntu/anaconda3/bin/python3 process.py