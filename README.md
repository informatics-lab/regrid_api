# Regridding API
Distributed regridding API

## Currently broken because...

So this won't currently work and will fail like:
```
ERROR:root:Error in main.
Traceback (most recent call last):
  File "process.py", line 279, in <module>
    main()
  File "process.py", line 270, in main
    channel.start_consuming()
  File "/opt/conda/lib/python3.6/site-packages/pika/adapters/blocking_connection.py", line 1681, in start_consuming
    self.connection.process_data_events(time_limit=None)
  File "/opt/conda/lib/python3.6/site-packages/pika/adapters/blocking_connection.py", line 656, in process_data_events
    self._dispatch_channel_events()
  File "/opt/conda/lib/python3.6/site-packages/pika/adapters/blocking_connection.py", line 469, in _dispatch_channel_events
    impl_channel._get_cookie()._dispatch_events()
  File "/opt/conda/lib/python3.6/site-packages/pika/adapters/blocking_connection.py", line 1310, in _dispatch_events
    evt.body)
  File "process.py", line 73, in process
    local_data_uris = results[list(results.keys())[0]]
IndexError: list index out of range
```

This is because the Dask workers are scaled by the scheduler based on how much 'work' there is, however
the fist job the `processor.py` is to download all the files onto the available workers of which there will be zero. The fix to this might be the Thredds based random access to NetCDF data on s3, then we wouldn't have to download the data first. This work is in progress.


### Running API locally:

Ensure the AWS env variables `AWS_ACCESS_KEY_ID` and  `AWS_SECRET_ACCESS_KEY`

```
docker-compose up --build
```
API is at `localhost:5000`

Make a `POST` with `Content-type` of `application/json` with a coverage in the body defined like:

```
{
  "type" : "Coverage",
  "domain" : {
    "type" : "Domain",
    "domainType" : "Grid",
    "axes": {
      "lat" : { "values": [x / 10.0 for x in range(300, 400)] },
      "lon" : { "values": [x / 10.0 for x in range(300, 400)]},
      "t" : { "values": ["2016-03-03T00:00:00UTC", "2016-03-03T00:10:00UTC", "2016-03-03T00:20:00UTC"] }
    },
    "referencing": [{
      "system": {
        "type": "GeographicCRS",
        "id": "http://www.opengis.net/def/crs/EPSG/0/4979"
      }
    }]
  },
  "parameters" : {
    "high_type_cloud_area_fraction": {
      "type" : "Parameter"
    },
    "air_pressure_at_sea_level": {
      "type" : "Parameter"
    }
  }
}
```
## Creating AWS keys
In order to create AWS keys with terraform and not store in plain text we will use gpg:

Install and set up
```
brew install gnupg
brew install pinentry-mac
echo "pinentry-program /usr/local/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
```

Add the below to `~/.bashrc` or equivalent (and run in current shell).

```
GPG_TTY=$(tty)
export GPG_TTY 
```

Then generate your keys:
```
gpg --gen-key # <- Follow instructions to create public/private keys
gpg --list-keys
```

Giving:

```
/Users/theo/.gnupg/pubring.kbx
------------------------------
pub   rsa2048 2017-08-18 [SC] [expires: 2019-08-18]
      DFHJK435BVD893JH449FGRHJK3454JK345KJ3453
uid           [ultimate] Your Name <your.name@place.co.uk>
sub   rsa2048 2017-08-18 [E] [expires: 2019-08-18]

```

Identify your public key 'pub' and the id for it `DFHJK435BVD893JH449FGRHJK3454JK345KJ3453` in the example above.

encode and export to an environment variable
```
export TF_VAR_publicKey=$(gpg --export DFHJK435BVD893JH449FGRHJK3454JK345KJ3453 | base64)
```

Then run `terraform apply` choosing a profile that has IAM privileges.

```
terraform plan --var bucketName=regrid-api-result --var awsProfile=admin
```

You should get output like:

```
id = FDJKEIOFN3KLDKL24HJS
secret = dfg43FG34gfd34Ffgdr....
```

The id is plain text and needs base 64 encoding before going into the `secrets.yaml` file

```
printf FDJKEIOFN3KLDKL24HJS | base64
```

The secret is base64 encode and gpg encoded. Run below to unencode, decript and encode again:

```
echo $(terraform state show aws_iam_access_key.regrid | grep encrypted_secret | tr -s ' ' | cut  -d " " -f 3 | base64 --decode | gpg --decrypt 2> /dev/null |  perl -pe 'chomp if eof' | base64 )
```

The result of this is what goes in `secrets.yaml` as `AWS_SECRET_ACCESS_KEY`.

A useful debug tool is to remove the final base64 encoding and setting your `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables to those derived and testing a command like `aws s3api list-objects --bucket regrid-api-result`

## Kubernetes

```
kubectl create -f namespace.yaml
kubectl create -f secrets.yaml
kubectl create -f config.yaml

kubectl create -f messaging.yaml

kubectl create -f dask-worker.yaml
kubectl create -f scheduler.yaml


kubectl create -f api.yaml
```


## Watch out!

If you get an error like:


```
ValueError: Invalid header value b'AWS4-HMAC-SHA256 Credential=DFADFGREESDGREWSDDFG\n/20170821/eu-west-1/s3/aws4_request, SignedHeaders=content-md5;content-type;host;x-amz-content-sha256;x-amz-date, Signature=09d23b116e7c42d5d9e3bc6119ebb4a92d4531ac41c9307283d92c1254960d15'
100.96.67.8 - - [21/Aug/2017 09:16:01] "POST / HTTP/1.1" 500 -
```
When the `api.py` script is run then there are probably newlines (likely trailing) in the AWS details, likely before they were base64 encoded. 

## TODOs
Scale the dask cluster?
