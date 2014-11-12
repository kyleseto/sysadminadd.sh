sysadminadd.sh
==============

This script is used to create accounts with tmp password and to if available copy ssh public keys.
It also locks old accounts and during creation attempts to email the users for the accounts

This script needs to be run as root

For ssh keys to be copied it must exist in the same directory as this script and have the name (username).pub 
  eg:user kyle=kyle.pub
  
This is a primitive script that calls a number of standard binaries.
While these are standard binaries the behaviour will change with the different versions and implemented flags.
Binaries called:
useradd
passwd
mkdir
chmod
sendmail (This should be tested and modified for different version and implementations.)
openssl
