try:
    import boto3                  
except ImportError:
    import boto as boto3

import os
import json
import uuid

sqs = boto3.resource('sqs', region_name='eu-west-1')
s3 = boto3.resource('s3', region_name='eu-west-1')
queue = sqs.get_queue_by_name(QueueName=os.environ['QUEUE_NAME'])
BUCKET = os.environ['BUCKET_NAME']




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

    if not set(['x','y','t']) == set( axes.keys()):
        raise ValueError('domain.axes must contain x, y and t exacally')
    

    is_non_0_array = lambda x: isinstance(x, list) and len(x) > 0
    if not all(is_non_0_array(axes[i].get('values')) for i in ['x','y','t']):
        raise ValueError('domin.x.values , domain.y.values, domain.t.values must all be non 0 arrays')
    

    referencing = domain.get('referencing', [])
    if not (isinstance(referencing, list) and len(referencing) ==1):
        raise ValueError('referencing must be a length 1 array')

    
    system = referencing[0].get('system', {'type':None, 'id':None})
    
    if not (system['type'] == "GeographicCRS" and system["id"] == "http://www.opengis.net/def/crs/EPSG/0/4979"): 
        raise ValueError('referencing[0].system.type must equal GeographicCRS' +
                         ' and referencing[0].system.id must equal http://www.opengis.net/def/crs/EPSG/0/4979')
    
    return True
    

def make_status_file_bytes():
    return json.dumps({"status":"pending"}).encode('utf-8')

def upload_status_file(request_id):
    s3.Bucket(BUCKET).put_object(
        Key="%s/status" % request_id, 
        Body=make_status_file_bytes(), 
        ContentType='application/json')
    return "https://s3-eu-west-1.amazonaws.com/%s/%s/status" % (BUCKET, request_id)

def aws_lambda_handeler(event, context): 

    try:
        is_valid(event)
    except ValueError as e:
        return {'bad_request': str(e)} # TODO: currently any response is a 200. Should add a mapping in terraform.
    
    request_id = uuid.uuid4().hex
    status_url = upload_status_file(request_id)
    message = event
    message['status_url'] = status_url
    message['id'] = request_id

    response = queue.send_message(MessageBody=json.dumps(message))
    

    return {
        "status":status_url,
        "message_info":response,
    }
