import boto3
import io
import paramiko
import os
from aws_lambda_powertools import Logger

logger = Logger(service="download")
filename = "example.txt"

@logger.inject_lambda_context
def main(event, context):
    
    host = os.environ['source_host']
    port = 22
    username = os.environ['username']
    file = event.get("filename", filename)
    intermediate_bucket = os.environ['intermediate_bucket']
    
    logger.info({
        "operation": "Getting RSA Key"
    })
    client = boto3.client('ssm')
    private_key = client.get_parameter(
        Name="/sftp/sftp_password",
        WithDecryption=True
    )['Parameter']['Value']


    p_key = paramiko.RSAKey.from_private_key(io.StringIO(private_key))
    transport = paramiko.Transport((host, port))

    logger.info({
        "operation": "Connecting to sFTP Server"
    })
    transport.connect(username=username, pkey=p_key)
    sftp = paramiko.SFTPClient.from_transport(transport)

    logger.info({
        "operation": "Getting filename Example"
    })
    sftp.get(file, f"/tmp/{file}")


    logger.info({
        "operation": "Uploading to S3"
    })
    s3_client = boto3.client('s3')
    s3_client.upload_file(f"/tmp/{file}", intermediate_bucket, file)
    response = s3_client.head_object(
        Bucket=intermediate_bucket,
        Key=file
    )

    logger.info({
        "operation": f"{file} Object saved to s3"
    })

    return {
        "file": file,
        "size": response['ContentLength'],
        "ETag": response['ETag']
    }