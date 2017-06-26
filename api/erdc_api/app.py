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

if __name__ == "__main__":
    app.run('0.0.0.0')
