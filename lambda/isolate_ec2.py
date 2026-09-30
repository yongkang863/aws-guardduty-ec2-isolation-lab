import boto3
import os
import json

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    quarantine_sg_id = os.environ.get('QUARANTINE_SG_ID')

    print(f"Received GuardDuty Event: {json.dumps(event)}")

    try:
        # Extract the EC2 Instance ID from the GuardDuty finding JSON
        instance_id = event['detail']['resource']['instanceDetails']['instanceId']

        print(f"Initiating isolation for compromised instance: {instance_id}")

        # Swap the instance's Security Group to the Quarantine SG
        ec2.modify_instance_attribute(
            InstanceId=instance_id,
            Groups=[quarantine_sg_id]
        )

        success_msg = f"Successfully isolated instance {instance_id} by applying Quarantine SG: {quarantine_sg_id}"
        print(success_msg)

        return {
            'statusCode': 200,
            'body': json.dumps(success_msg)
        }

    except Exception as e:
        print(f"Error processing GuardDuty finding: {str(e)}")
        raise e