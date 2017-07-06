# ERDC Regridding API
API for regriding MOGREPS data

# Gotchas

Current version of Terraform (0.9.8) file provisner fails with symlinks. Make sure there arn't any such as those created by conda in a `bin` folder when doing `source activate <my_env>`.

Set up account id var
export TF_VAR_aws_account_id=$AWS_ACCOUNT_ID

Ensure bucket already exists. Not managed by Terraform


### Running API locally:

```
export QUEUE_NAME="erdc-api-to-process"
export BUCKET_NAME="regrid-api-result"
python test_apy.py
```

### Running processor locally
Set up your python environment with `python 3`, `dask`, `distributed` and `iris` I suggest using conda

```
conda conda create -n erdc_api python=3 dask=x.x.x distributed=y.y.y iris=z.z.z


```

See `terraform/vars.tf` for current version numbers.

Ensure that the environment is active

```source activate erdc_api```

Then run the `dask-scheduler`, `dask-worker` and `process/process.py` (you might like to use different terminal windows).

```
dask-scheduler &
dask-worker localhost:8786 --nprocs 1 --nthreads 1 &
python process/process.py
```

If you get an error like:

```
our terminal does not properly support unicode text required by command line
utilities running Python 3.  This is commonly solved by specifying encoding
environment variables, though exact solutions may depend on your system:
    $ export LC_ALL=C.UTF-8
    $ export LANG=C.UTF-8
For more information see: http://click.pocoo.org/5/python3/
```

Try setting up your environment variables like: 

```
export LC_ALL=en_GB.UTF-8
export LANG=en_GB.UTF-8
export LC_CTYPE=en_GB.UTF-8
```

You may wish to add this to `.bashrc`.

If that still fails ensure that you are in your `erdc_api` environment and run:

```python -c "import click; click._unicodefun._verify_python3_env();"```

Which might give you some clues.


## TODOs
Avoid elastic load balancer? maybe use a self editing DNS entry.