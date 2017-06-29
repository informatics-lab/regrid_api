# API

## Pre-req
- [mini conda](https://conda.io/docs/install/quick.html#miniconda-quick-install-requirements)

## Setup

```
brew install 
cd <location of this read me>
conda remove --name erdc_api --all # may be required if not the first time
conda create --name erdc_api python=3 flask boto3
source activate erdc_api

### Development
