try:
    import boto3                  
except ImportError:
    import boto as boto3

import logging
import os
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.resource('sqs', region_name='eu-west-1')
s3 = boto3.resource('s3', region_name='eu-west-1')
queue = sqs.get_queue_by_name(QueueName=os.environ['QUEUE_NAME'])
def aws_lambda_handeler(event, context): 
    logger.info('got event{}'.format(event))
    response = queue.send_message(MessageBody=json.dumps(event))
    return {"msg":"hello"}
