# String that uniquely identifies your GnuPG UID (e-mail address usually works)
D_GPG_UID='email@example.com'

## Path to can file - double-encrypted backup of your primary keypair
#
## When you first use this primer, can file at this path may not exist at all - 
#. it will be created automatically
#
## Ideas for what this location might be:
#.  * Mounted USB drive - unmount and secure the drive once you're done
#.  * Cloud directory (e.g., Dropbox) - use this if you trust yourself to 
#.    remember can file password
#
D_GPG_KEY_CAN_LOCATION="$HOME/Dropbox/secret-storage/safebox-gpg.tar.can"