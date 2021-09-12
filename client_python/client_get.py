import paramiko
"""
Downloads document to source bucket
"""

host = "s-267d264d72c344c09.server.transfer.ap-southeast-1.amazonaws.com"
port = 22
username = "sftpUser"
key_file = "../transfer-key"

mykey = paramiko.RSAKey.from_private_key_file(key_file)
transport = paramiko.Transport((host, port))
transport.connect(username=username, pkey=mykey)
sftp = paramiko.SFTPClient.from_transport(transport)

files = sftp.listdir()
for file in files:
    sftp.get(file, f"./files/{file}")

sftp.close()
transport.close()