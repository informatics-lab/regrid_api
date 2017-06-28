import boto3
import time
import sys


print ('Processor starting')

sqs = boto3.resource('sqs', region_name='eu-west-1')
s3 = boto3.resource('s3', region_name='eu-west-1')
# queue = sqs.get_queue_by_name(QueueName=os.environ['QUEUE_NAME']) # TODO: Get from env var
queue = sqs.get_queue_by_name(QueueName="erdc-api-to-process")


# def process_message(msg):
#     msg = json.loads(msg.body)

def process_all_messages():
    for msg in queue.receive_messages():
        # process_message(msg) #TODO: actually do something with it.
        print("Message processed, will delete")
        msg.delete()


if __name__ == '__main__':
    print ('Waiting for messages')
    while True:
        process_all_messages()
        print("sleep for 20 secs...")
        sys.stdout.flush()
        time.sleep(20)

        