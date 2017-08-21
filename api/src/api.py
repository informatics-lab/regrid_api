try:
    import boto3                  
except ImportError:
    import boto as boto3

from flask import Flask, request, jsonify
import pika
import os
import json
import uuid
import logging

root = logging.getLogger()
root.setLevel(logging.DEBUG)

s3 = boto3.resource('s3', region_name='eu-west-1') # TODO: do we need region? shouldn't be hard coded.

QUEUE_NAME = os.environ['QUEUE_NAME']
BROKER_HOST = os.environ['MQ_HOST']
BUCKET_NAME = os.environ['BUCKET_NAME']


def is_valid(coverage):
    if not coverage.get('type', False) == "Coverage":
        raise ValueError("Must provied a 'type' and must be 'Coverage'")
    
    domain = coverage.get('domain', None)
    if not (domain and isinstance(domain, dict)):
        raise ValueError("Must provied a domain")
    
    

    if not domain.get('type', None) == 'Domain':
        raise ValueError('dmain.type must be Domain')
    
    if not domain.get('domainType', None) == 'Grid':
        raise ValueError('domain.domainType must be Grid')
    
    axes = domain.get('axes',{})

    if not set(['lat','lon','t']) == set( axes.keys()):
        raise ValueError('domain.axes must contain lat, lon and t exacally')
    

    is_non_0_array = lambda x: isinstance(x, list) and len(x) > 0
    if not all(is_non_0_array(axes[i].get('values')) for i in ['lat','lon','t']):
        raise ValueError('domin.lat.values , domain.lon.values, domain.t.values must all be non 0 arrays')
    

    referencing = domain.get('referencing', [])
    if not (isinstance(referencing, list) and len(referencing) ==1):
        raise ValueError('referencing must be a length 1 array')

    
    system = referencing[0].get('system', {'type':None, 'id':None})
    
    if not (system['type'] == "GeographicCRS" and system["id"] == "http://www.opengis.net/def/crs/EPSG/0/4979"): 
        raise ValueError('referencing[0].system.type must equal GeographicCRS' +
                         ' and referencing[0].system.id must equal http://www.opengis.net/def/crs/EPSG/0/4979')

    
    params = coverage.get('parameters', {})
    param_names = params.keys()
    avalaliable_params = ['wet_bulb_freezing_level_altitude', 'air_pressure_at_sea_level', 'dew_point_temperature',
          'fog_area_fraction', 'visibility_in_air', 'high_type_cloud_area_fraction']
    if len(param_names) < 1:
        raise ValueError('Must supply at least one parameter in the parameters section')
    
    if not all(requested in avalaliable_params for requested in param_names):
        raise ValueError('Parameters can only be one or more of %s' % avalaliable_params)
    
    return True
    

def make_status_file_bytes():
    return json.dumps({"status":"pending"}).encode('utf-8')

def upload_status_file(request_id):
    s3.Bucket(BUCKET_NAME).put_object(
        Key="%s/status" % request_id, 
        Body=make_status_file_bytes(), 
        ContentType='application/json')
    return "https://s3-eu-west-1.amazonaws.com/%s/%s/status" % (BUCKET_NAME, request_id)



app = Flask(__name__)
@app.route("/", methods=['POST'])
def aws_lambda_handeler(): 
    coverage = request.get_json() 
    try:
        is_valid(coverage)
    except ValueError as e:
        return jsonify({'bad_request': str(e)} )# TODO: currently any response is a 200. Should add a mapping in terraform.
    request_id = uuid.uuid4().hex
    status_url = upload_status_file(request_id)
    message = coverage
    message['status_url'] = status_url
    message['id'] = request_id

    connection = pika.BlockingConnection(pika.ConnectionParameters(BROKER_HOST))
    channel = connection.channel()
    channel.queue_declare(queue=QUEUE_NAME)
    channel.basic_publish(exchange='', routing_key=QUEUE_NAME,
                            body=json.dumps(message))
    connection.close()

    return jsonify({
        "status":status_url
    })


@app.route("/hi")
def hi():
    logging.info('dets')
    logging.info(QUEUE_NAME)
    logging.info(BROKER_HOST)
    logging.info(BUCKET_NAME)
    logging.info('"%s"' % os.environ['AWS_ACCESS_KEY_ID'])
    logging.info('"%s"' % os.environ['AWS_SECRET_ACCESS_KEY'][8:12])
    logging.info('"%s"' % os.environ['AWS_SECRET_ACCESS_KEY'][23:29])
    logging.info('"%s"' % os.environ['AWS_SECRET_ACCESS_KEY'][-3:-1])
    logging.info('dets over')

    return 'hi to you on this day :)'



if __name__ == "__main__":
    app.run(host="0.0.0.0")