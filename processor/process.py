import boto3            
import time
import sys
import distributed

print ('Processor starting')

sqs = boto3.resource('sqs', region_name='eu-west-1')
s3 = boto3.resource('s3', region_name='eu-west-1')
# queue = sqs.get_queue_by_name(QueueName=os.environ['QUEUE_NAME']) # TODO: Get from env var
queue = sqs.get_queue_by_name(QueueName="erdc-api-to-process")


print('connected to sqs')

client = None;
while not client:
    try:
        client = distributed.Client('localhost:8786') 
    except Exception as e:
        print(e)

print('connected to scheduler. ', client)

while len(client.ncores().keys()) < 1:
    print("Client not ready ", client)
    time.sleep(30)

def process_all_messages():
    for msg in queue.receive_messages():
        print("Clinet says ", client, 'body of message:')
        print(msg.body)
        print("Message processed, will delete")
        msg.delete()


if __name__ == '__main__':
    print ('Waiting for messages')
    while True:
        process_all_messages()
        print("sleep for 20 secs...")
        sys.stdout.flush()
        time.sleep(20)

        