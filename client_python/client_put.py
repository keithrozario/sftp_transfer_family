import paramiko
import os
from datetime import datetime, timezone
"""
Uploads document to destination bucket
"""

host = "s-eefda0ca3d624fd2b.server.transfer.ap-southeast-1.amazonaws.com"
port = 22
username = "sftpUser"
key_file = "../transfer-key"

mykey = paramiko.RSAKey.from_private_key_file(key_file)
transport = paramiko.Transport((host, port))
transport.connect(username=username, pkey=mykey)
sftp = paramiko.SFTPClient.from_transport(transport)

# List all files in a directory using os.listdir
basepath = './files/'
for entry in os.listdir(basepath):
    if os.path.isfile(os.path.join(basepath, entry)):
        response = sftp.put(os.path.join(basepath, entry), entry)
        print(datetime.fromtimestamp(response.st_mtime, tz=timezone.utc))

print(sftp.listdir())
sftp.close()
transport.close()
