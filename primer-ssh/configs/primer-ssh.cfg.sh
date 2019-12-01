# SSH working directory
D_SSH_DIR="$HOME/.ssh"

## Path to can file - double-encrypted backup of SSH work dir contents
#
## When you first use this primer, can file at this path may not exist at all - 
#. it will be created automatically
#
## Ideas for what this location might be:
#.  * Mounted USB drive - unmount and secure the drive once you're done
#.  * Cloud directory (e.g., Dropbox) - use this if you trust yourself to 
#.    remember can file password
#
D_SSH_CAN_LOCATION="$HOME/Dropbox/secret-storage/safebox-ssh.tar.can"