import uuid
import boto3
from flask import Flask, request, jsonify

app = Flask(__name__)
BUCKET_NAME = "ERDC-API"

@app.route("/hello/<first>/<last>")
def climate(first, last):
    return jsonify({
        'resp': "Hello {first} {last}".format(first=first, last=last)
    })

@app.route("/sched/status")
def stats():
    return _proxy


def get_s3_url(id):
    return 'https://s3-eu-west-1.amazonaws.com/{}/{}.png'.format(BUCKET_NAME, id)


def upload_image(byte_data):
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(BUCKET_NAME)
    id = str(uuid.uuid4())
    bucket.put_object(
        Body=byte_data,
        ContentType='image/png',
        Key='{}.png'.format(id),
        ACL='public-read')
    return get_s3_url(id)

from flask import request, Response
import requests

def _proxy(*args, **kwargs):
    resp = requests.request(
        method=request.method,
        url=request.url.replace('old-domain.com', 'new-domain.com'),
        headers={key: value for (key, value) in request.headers if key != 'Host'},
        data=request.get_data(),
        cookies=request.cookies,
        allow_redirects=False)

    excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
    headers = [(name, value) for (name, value) in resp.raw.headers.items()
               if name.lower() not in excluded_headers]

    response = Response(resp.content, resp.status_code, headers)
    return response

if __name__ == "__main__":
    app.run('0.0.0.0')
