import boto3            
import time
import sys
import distributed
import os
import json

print ('Processor starting')

# QUEUE_NAME = os.environ['QUEUE_NAME']
QUEUE_NAME = os.environ['QUEUE_NAME'] 
BUCKET = os.environ['BUCKET_NAME']

print ("Queue = %s" % QUEUE_NAME)

sqs = boto3.resource('sqs', region_name='eu-west-1')
s3 = boto3.resource('s3', region_name='eu-west-1')
queue = sqs.get_queue_by_name(QueueName=QUEUE_NAME)


print('connected to sqs')

client = None;
while not client:
    try:
        client = distributed.Client('localhost:8786') 
    except Exception as e:
        print(e)

print('connected to scheduler.', client)

while len(client.ncores().keys()) < 1:
    print("Client not ready ", client)
    time.sleep(30)


def make_status_file_bytes():
    return json.dumps({"status":"done"}).encode('utf-8')

def upload_status_file(job_id):
    s3.Bucket(BUCKET).put_object(
        Key="%s/status" % job_id, 
        Body=make_status_file_bytes(), 
        ContentType='application/json')
    return "https://s3-eu-west-1.amazonaws.com/%s/%s/status" % (BUCKET, job_id)


def process(msg):
    body = json.loads(msg.body)
    print(body)
    job_id = body['id']
    upload_status_file(job_id)
    print("Message processed, will delete")
    msg.delete()


def process_all_messages():
    for msg in queue.receive_messages():
        try:
            process(msg)
        except Exception as e:
            print (e)
        

if __name__ == '__main__':
    print ('Waiting for messages')
    while True:
        process_all_messages()
        print("sleep for 20 secs...")
        sys.stdout.flush()
        time.sleep(20)

        