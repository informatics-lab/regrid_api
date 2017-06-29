#!/bin/bash
export QUEUE_NAME=${input_queue_name}
export PATH="/home/ubuntu/anaconda3/bin:$PATH"
conda install dask distributed boto3 -y # TODO: specify versions.
dask-scheduler --port 8786 --bokeh-port 8787 &
cat <<EOT >> process.py
${script}
EOT
/home/ubuntu/anaconda3/bin/python3 process.py