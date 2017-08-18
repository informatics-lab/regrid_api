# Regridding API
Distributed regridding API

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
echo FDJKEIOFN3KLDKL24HJS | base64
```

The secret is base64 encode and gpg encoded. Run below to unencode.

```
 terraform state show aws_iam_access_key.regrid | grep encrypted_secret | tr -s ' ' | cut  -d " " -f 3 | base64 --decode | gpg --decrypt 
 ```

 Which give something like 

 ```
 gpg: encrypted with 2048-bit RSA key, ID 34545SFG43RR, created 2017-08-18
      "Your Name <your.name@place.co.uk>"
4dahjkl4jlkfda+dfjkl34/dfjkl33kljsi4jklD%
```

Take the key (ignore trailing % or other odd symbols) and base64 encode

```
echo 4dahjkl4jlkfda+dfjkl34/dfjkl33kljsi4jklD | base64
```

The result of this is what goes in `secrets.yaml` as `AWS_SECRET_ACCESS_KEY`.

A useful debug tool is to remove the final base64 encoding and setting your `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables to those derived and testing a command like `aws s3api list-objects --bucket regrid-api-result`

## TODOs
Scale the dask cluster?
