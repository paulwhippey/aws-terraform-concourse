"""
Listens SNS notifications from auto-scaling lifecycle hooks, indicating that it wishes to scale-in the instance.
Executes the 'retire worker' script on the selected instance via Systems Manager.
"""
import os
import boto3
import json


class Handler:
    def __init__(self, ssm_client):
        self.ssm_client = ssm_client

    def process(self, event):
        print("Received event: " + json.dumps(event, indent=2))

        for record in event['Records']:
            message = json.loads(record['Sns']['Message'])
            if message['LifecycleTransition'] == 'autoscaling:EC2_INSTANCE_TERMINATING':
                instance = message['EC2InstanceId']
                result = self.ssm_client.send_command(
                    DocumentName=os.getenv('DOCUMENT_NAME'),
                    InstanceIds=[instance],
                    TimeoutSeconds=7200,
                    CloudWatchOutputConfig={
                        'CloudWatchOutputEnabled': True,
                    }
                )
                print(result)


def handler(event, context):
    h = Handler(boto3.client('ssm'))
    h.process(event)
