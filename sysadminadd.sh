#!/bin/bash
#######################################################################################################################
# Version 1.12
#
# Created by kyle 
#
# This script is used to create accounts with tmp password and to if available copy ssh public keys.
# It also locks old accounts and during creation attempts to email the users for the accounts
#
# This script needs to be run as root
#
# For ssh keys to be copied it must exist in the same directory as this script and have the name (username).pub 
#     eg:user kyle=kyle.pub
#
#######################################################################################################################

#email string for the domain of the account
email=<"company.org">
#default shell you want for users
BASH_LOC="/bin/bash"
#default group users will be placed in
GROUP="100"

# Users details
USERS=( "kyle" "test" "appuser")
UIDS=( "610111" "151414" "10191" )
NAME=( "Kyle Account" "Test User" "Application Account" )

# Accounts to lock
LOCKUSERS=( "OldUser" "OlderUser" "DodgeAdminUser" )

#Check that the user is root
#root permission are need for some of the binaries that are called
if [ $EUID -eq 0 ]; then

	# Check if the utilities exist to run script
	PROGS="id chage chpasswd passwd sendmail useradd" 

	# Run through the list of need utilities
	for i in $PROGS
	do
		# Check if the computer can find it
		if ( ! `which $i > /dev/null 2>&1` );then
			# If the untilities doesn't exist print error and then exit
			echo "Program '$i' does not exist, exiting..."
			exit 69
		fi
	done

	#Counter for the users to be looped 
	COUNT=0

	echo "Creating SysAdmin accounts"
	while [ $COUNT -lt ${#USERS[@]} ]
	do
		#Set flags to false
		passbool="0"
		sshbool="0"

		#Gets username and homedir
		username=${USERS[$COUNT]}
		homedir="/home/$username"
		# Check if the account already exists
		if id -u "$username" >/dev/null 2>&1 ; then
			echo "$username:Already exists"
		else
			# Create account for those that don't exist
			echo "$username" is being created 
			# Create a random password
			PASS=$(openssl rand -base64 12 | cut -c 1-10)
			# Create the account 
			useradd -c "${NAME[$COUNT]}" -s "$BASH_LOC" -u "${UIDS[$COUNT]}" -g "$GROUP" -d "$homedir" -G sys "$username"
			echo "$PASS"
			# Set password for the account
			echo "$username:$PASS" | chpasswd
			chage -d 0 "$username"
			# Set the flag to say password has been set for the account
			passbool="1"
		fi
		if [ -f "$username".pub ] ; then
			#Make the directory for the users .ssh profile
			mkdir -p "$homedir"/.ssh/
			chmod -v 700 "$homedir"/
			#Check the users has a public key to be placed on the machine
			#force copy the key to their ssh profile
			echo "$username:Public key is being copied"
			cat "$username".pub >> "$homedir"/.ssh/authorized_keys
			chmod -v 600 "$homedir"/.ssh/authorized_keys
			chown -v "$username" "$homedir"/
			chown -v "$username" "$homedir"/.ssh/
			chown -v "$username" "$homedir"/.ssh/authorized_keys
			#Test if it worked
			echo "$username:Key copied correctly"
			sshbool="1"
		else 
			#No public key for this user was created
			echo "$username: No .pub file found"
		fi
		# Send an email to make sure that they know an account was created for them on this machine
		if [ $passbool -eq "1" ] ; then
			if [ $sshbool -eq "1" ]; then
				# Emails user that key and ssh has been copied
				(
					echo "Subject:Account Created on $(hostname -f) with tmp password $PASS and ssh key copied"
					echo "From:root@$(hostname -f)"
					echo "Your temporary password is $PASS . Your ssh public key has also been added."
				)  | sendmail "$username"@"$email" ;
				echo "$username:Account created and ssh key copied"
			else
				# Emails users that their account has been created
				(
					echo "Subject:Account Created on $(hostname -f) with temp password of $PASS"
					echo "From:root@$(hostname -f)"
					echo "Your temporary password is $PASS."
				)  | sendmail "$username"@"$email" ;
				echo "$username:Account created with tmp password"
			fi
		elif [ $sshbool -eq "1" ] ; then
			# Emails user to inform them of keys being copied
			(
				echo "Subject:Your ssh key has been copied to $(hostname -f) for your existing account"
				echo "From:root@$(hostname -f)"
				echo "Your account already exists on$(hostname -f) so we copied your ssh key into your profile"
			)  | sendmail "$username"@"$email" ;
			echo "$username:Account already existed copied ssh key"
		else
			echo "$username:Account not created and key not copied. No email sent."
		fi
		((COUNT=COUNT+1))
	done 

	# Append the sys group to the Sudoers file
	echo "%sys	ALL=(ALL)	ALL" >> /etc/sudoers
	echo "sys Group has been appended to sudoers file"

	#Lock old accounts
	echo " "
	echo "Lock old accounts"
	#Check the usernames in the file against the system 
	COUNT=0
	while [ $COUNT -lt ${#LOCKUSERS[@]} ]
	do
		#Gets username
		lockuser=${LOCKUSERS[$COUNT]}
		#Checks if the account exists
		if id -u "$lockuser" >/dev/null 2>&1; then
			echo "$lockuser:Locking account"
			# Lock the account
			passwd "$lockuser" -l
		else 
			echo "   $lockuser:Does not exist"
		fi
		# loops through users
		((COUNT=COUNT+1))
	done
else
	# Script need root permissions
	echo "This script should be run as root"
fi
