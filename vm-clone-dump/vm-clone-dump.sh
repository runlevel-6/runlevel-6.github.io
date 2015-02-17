#!/bin/bash
#
# Ken Zahorec 2015-02-16
#
# This script prepares hypervisor VMs for backup and then clones them to a backup area using libvirt.
# It emphasizes backuppc processing by suspending any running VMs before calling virt-cone to create VM dumps in a desginated dump area.
# 
# This script first looks for currently running VMs and suspends each of them.
# It calls virt-cone script on each of the suspended VMs
# It them enumerates the VMs in the shutoff state and runs virt-clone on each of them.
# Finally, it resumes the previously running VMs.

# NOTE: This script does NOT dump paused or transitioning VMs--these VMs are not dumped, so will not be backed up via backuppc.
# VMs need to be either shutdown (inactive) or running to be backed up.
# When the script changes. please keep the version number updated via "year.month.day.increment" as follows.
version="2015.02.09.00"
# Exit on use of non-set variables
set -o nounset
# Exit on any errors returned
set -o errexit
# target_script_dir is set to the directory where you run this script and also the location of the VMs dump data.
target_script_dir=/var/lib/libvirt/images/virt-backup

# define logfile, name of this script, a date-time stamp
logfile="dump.log"
lockfile="dump.lock"
dump_subdir="dump"
script_name=${0##*/}
date_time=$(date)
operation_type=""


###################################################
function print_run_time () {

# Get current time in seconds
script_now_sec=$(date +%s)
# Difference between now and start time is the run time	
script_run_time_sec=$((${script_now_sec}-${script_start_sec}))
script_run_time_min=$((${script_run_time_sec}/60))
script_run_time_hour=$((${script_run_time_min}/60))
script_run_time_day=$((${script_run_time_hour}/24)) # hopefully we need go no further

if [ ${script_run_time_day} -ge 2 ]; then
	run_time="approximately $script_run_time_day days"
elif [ ${script_run_time_hour} -ge 4 ]; then
	run_time="approximately $script_run_time_hour hours"
elif [ ${script_run_time_min} -ge 10 ]; then
	run_time="approximately $script_run_time_min minutes"
else
	run_time="$script_run_time_sec seconds"
fi

echo " ==> elapsed $script_run_time_sec seconds"
echo " ==> $operation_type required $run_time"
}


###################################################
function create_and_dump_temporary_clone () {
	# grab the first argument which contains the VM name to use
	vm_target="$1"

	date_time=$(date)
	echo "$date_time : create_and_dump_temporary_clone will attempt to dump VM $vm_target"
	clone_stamp="c"

	# Create the specific vm dump subdirectory if it does not already exist.
	mkdir -p "$DUMPDIR/$dump_subdir/$vm_target"

	# Overall name of the temporary clone can not exceed 50 characters or virt-clone will fail.
	# Use alternate clone stamp and shorten original name if character limit would exceed 50.
	if [ ${#i} -gt 48 ]; then
		# We have to truncate the last part of the name because it it too long.
		# Produce a 6 char unique postpend stamp for clone names xxxxxx (hour-minute-second)
		alt_clone_stamp=$(date +%H%M%S)
		# Truncate the original name
		vm_target_short=${vm_target:0:42}
		# Combine the truncated name with the clone stamp to create the alt_clone_name
		alt_clone_name="$vm_target_short-$alt_clone_stamp"
		echo "VM name $vm_target-$clone_stamp is greater than 50 characters. Using $alt_clone_name instead."
		clone_name="$alt_clone_name"
		sleep 1
		# Sleep briefly to insure we never get an identical alt_clone_stamp during the same dump operation.
		# We never want to produce a name collision when creating clones or they will fail.
	else
		clone_name="$vm_target-$clone_stamp"
	fi

	# We need to enhance this area of the script to support multiple virtual drives on the VM.
	# Some vms can be setup with mutilple virtual hard disks. We need to enumerate them and provide
	# a target in the temporary clone for them by repeat of the -f parameter in the virt-clone command.
	# Use of the virsh command with domblklist parameter can help us here.	
	# v?? is VirtIO disk, h?? is VirtIDE disk, S?? is Virt SCSI
	# "-" imples a CDROM drive that is disonnected. For example:
	#
	# [root@et-virt105 virt-backup]# virsh domblklist puppetmaster-clone-initialstate
	# Target     Source
	# ------------------------------------------------
	# vda        /var/lib/libvirt/images/puppetmaster-clone-initialstate.img
	# vdb        /var/lib/libvirt/images/puppetmaster-clone-initialstate-1.img
	# hda        /var/lib/libvirt/images/puppetmaster-clone-initialstate-2.img
	# hdc        -
	# sda        /var/lib/libvirt/images/puppetmaster-clone-initialstate-3.img
	#
	# We can pull information we need from the list. Generally speaking, the number
	# of filespecs in the list imply the number of virtual storage devices.
	# Something as simple as this:
	#
	# [root@et-virt105 virt-backup]# virsh domblklist puppetmaster-clone-initialstate | grep /
	# vda        /var/lib/libvirt/images/puppetmaster-clone-initialstate.img
	# vdb        /var/lib/libvirt/images/puppetmaster-clone-initialstate-1.img
	# hda        /var/lib/libvirt/images/puppetmaster-clone-initialstate-2.img
	# sda        /var/lib/libvirt/images/puppetmaster-clone-initialstate-3.img
	#
	# Use of virt-clone:
	# We can pass more "-f" option entries than virtual disks, it will populate only
	# as many as it needs. Read-only drives will remain rooted to the original in the
	# system in the new clone XML file. Read-only virtual storage drives are not dumped. 

	num_drives=$(virsh domblklist ${vm_target} | grep / | wc -l)
	echo "VM $vm_target has $num_drives virtual disks"
	
	# Check number of virtual drives to make sure there are no more than 5, a reasonable limit.
	if [ ${num_drives} -le 5 ]; then
		echo "$date_time : calling virt-clone to clone vm $vm_target ---> $clone_name"

		set +e # Disable errexit...keep chugging even if the virt-clone commands fail for this particular VM.
		# The command pipe to grep below reduces a rather lengthy output of continued progress updates during virt-clone process.
		virt-clone --connect=qemu:///system -o "$vm_target" -n "$clone_name" \
		 -f "$DUMPDIR/$dump_subdir/$vm_target/$clone_name-1.img" \
		 -f "$DUMPDIR/$dump_subdir/$vm_target/$clone_name-2.img" \
		 -f "$DUMPDIR/$dump_subdir/$vm_target/$clone_name-3.img" \
		 -f "$DUMPDIR/$dump_subdir/$vm_target/$clone_name-4.img" \
		 -f "$DUMPDIR/$dump_subdir/$vm_target/$clone_name-5.img" | grep ${clone_name}

		# Copy both the original VM XML and the temporary cloned VM XML files to the dump area.
		cp -pv  "/etc/libvirt/qemu/$vm_target.xml"  "$DUMPDIR/$dump_subdir/$vm_target"
		cp -pv  "/etc/libvirt/qemu/$clone_name.xml"  "$DUMPDIR/$dump_subdir/$vm_target"
		
		# Undefine the clone. This does not delete the clones disk(s) image(s), which remain in the dump area.
		echo "$date_time : calling virsh undefine to remove temporary clone $clone_name"
		virsh undefine "$clone_name"
		set +e # Return to normal errexit bahavior. Exit script on any errors.

		# Check to see if the image was created. If virt disk is read-only in VM, it will not get dumped.
		# We need to get this information to the log file. Users need to know that read-only drives will
		# not get dumped for backup.
		date_time=$(date)
		for index in $(seq 1 ${num_drives});
		do
			if [ -e "$DUMPDIR/$dump_subdir/$vm_target/${clone_name}-${index}.img"  ]; then
				echo -e "$date_time : SUCCESS - dump virtual storage disk ${clone_name}-${index} succeeded \n"
			else
				# Copy of the vm virtual storage disk image failed
				echo "$date_time : WARNING - dump of virtual storage volume ${clone_name}-${index} ==> FAILED <=="
				echo -e "==> Review VM settings. Perhaps a mounted CDROM image or other type of read-only storage is mounted.\n"
			fi
		done
	else
		echo "====> ERROR : VM $vm_target has more than 5 virtual disks, it will not be dumped."
	fi
}
#########################################################
#########################################################
# Script processing basically starts here

################# script logging control ############
# FOR DEBUGGING USE ONLY: From this point onward, all console std out and std
# err output gets appended to the log file.  Normally we do not use this as all
# stream outputs go to the backuppc logs for this host.  If script is not run
# from backup area and we used this feature, we would lose log information.
# exec 3>&1 1>>${logfile} 2>&1

############### script dependencies check ###########
### check for virsh
if ! [ -x "$(command -v virsh)" ]; then
  echo 'The virsh utility appears to be missing. This script is designed for KVM/Qemu/libvirt systems.' >&2
  exit
fi
### check for virt-clone
if ! [ -x "$(command -v virt-clone)" ]; then
  echo 'The virt-clone utility appears to be missing. Perhaps install package virt-install.' >&2
  exit
fi

# Set defaults
DUMPDIR="/var/lib/libvirt/images/virt-backup"
CONCURRENT=0
DUMP=0
CLEAN=0
HELP=0

for i in "$@"
do
# echo "    $i"
case $i in
	-d=*|--dumpdir=*)
	DUMPDIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
	# If present, remove a trailing slash
	DUMPDIR=${DUMPDIR%/}
	;;
	-o|--concurrent)
	CONCURRENT=1
	DUMP=1
	;;
	-d|--dump)
	DUMP=1
	;;
	-c|--clean)
	CLEAN=1
	operation_type="dump cleanup"
	;;
	-h|--help)
	HELP=1
	;;
	*)
	echo "==>WARNING: An unknown or unsupported parameter: $i"
	HELP=1
	;;
esac
done

if [ $HELP -eq 1 ]; then
echo -e "$script_name version $version help information:\nUsage:\n"
echo -n "  $script_name"
echo -e ' [ -d | --dump ]|[ -o | --concurrent ] [ -c | --clean ][ -d=(dir) | --dumpdir=(dir) ] [-h | --help]
----------------------------------------------------------------------------
  This script is designed to be used for pre-backup and post-backup dump and
  cleanup operations in conjunction with BackupPC or any other enterprise grade
  backup facility. This script provides a data dump of VM data at the
  hypervisor. It is designed to work with KVM/Qemu/libvirtd systems. It has been
  tested and used on CentOS v6.X and CentOS v7 systems.
  Seems reasonable that this script would run on Debian based KVM/Qemu/Libvirt
  systems as well.

  This script should be used during non-essential or non-business user times.
  It causes stress at the hypervisor due to the intense amount of IO required
  to move vm data.
-----------                                                 -------------------
Options are described below:

 -d | --dump
  Perform a normal clone dump operation of all running and shutdown VMs at the
  hypervisor.  This pauses all running VMs before cloning and dumping them.
  After dumping each vm, all of the previously running vms are then resumed.
  This provides least load at the hypervisor, but will result in unavailable
  vms during the time it takes the system to dump all of the vm data.

 -o | --concurrent
  Perform a high availability dump operation of all running and shutdown VMs at
  the hypervisor.  This will pause VMs individually and perform the clone dump,
  while other VMs remain running.

  On less capable servers, concurrent dumps can impact vm user experience
  because of limited IO capacity.  During the dump, other running VMs can
  become generally unresponsive resulting in user complaints. On more capable
  servers this option can limit vm downtime during dump operations.

 -c | --clean
  Perform a cleanup of the dumpdir location. This removes the dump lockfile and
  deletes all files that were previously dumped. It clears out the dump area to
  ready it for a future dump operation.

 -d=(dir) | --dumpdir=(dir)
  Specifying the dumpdir is not required, unless you want to use something other
  that the default value. The default dumpdir is
                                 /var/lib/libvirt/images/virt-backup
------------- Additional Info
  
  The dumpdir specified is used as the *parent* dump control directory. The
  dump subdirectory, "dump/", below the parent, is the actual target directory
  for the vm dump data. The dumpdir contains the lockfile control file and
  typically this script.
  
  You can place this script in the dumpdir and run it from there. This way you
  will get the very same script used for dumping, and cleanup, included in the
  backup data and it will remain on the system for backup use. Be sure to
  specify the dumpdir as the backup target in the BackupPC configuration for
  the hypervisor host.

  This script will not dump paused, or transitional vms. It will dump vms which
  are active running and/or inactive shutdown at invocation time. It will not
  dump images of vms which have their virtual disks set to read-only--it will
  dump only the vm XML for these vms.

  This script has not been tested with vms which are run without storage.
  Furthermore it requires that the vm be setup with a single virtual disk.
  Support for vms with multiple virtual disks is planned for near future.
'
exit
fi

echo "$date_time : **************** BEGIN $script_name version $version"

# Get current time in seconds
script_start_sec=$(date +%s)

if [ $CLEAN -eq 1 ]; then
echo " ==> Dump cleanup is requested. Proceeding..."
	# Cleanup the lock file
	if [ -e $DUMPDIR/${lockfile}  ]; then
		# Lockfile exists, delete it.
		echo "Deleting $DUMPDIR/$lockfile ..."
		rm -f "$DUMPDIR/$lockfile"
	else
		# Lockfile does not exist. Warn and continue.
		echo "$DUMPDIR/$lockfile was not detected - continuing anyway ..."
	fi

	# Cleanup the dump area
	if [ -e $DUMPDIR/${dump_subdir}  ]; then
		echo "Deleting data found at $DUMPDIR/$dump_subdir"
		rm -rf "$DUMPDIR/$dump_subdir"
	else
		echo "No VM dump data detected at $DUMPDIR/$dump_subdir"
	fi

	# Keep the dump-subdir directory available for possible manual restores from the backup server.
	# This may not be needed for restoration from backup server. It is here as a safeguard.
	echo "create new empty dump area $DUMPDIR/$dump_subdir"
	mkdir -p "$DUMPDIR/$dump_subdir"

	print_run_time

	date_time=$(date)
	echo "$date_time : **************** COMPLETED $script_name"

	# We are done, nothing else to do.
	exit
fi

if [ $DUMP -eq 1 ]; then
	operation_type="STANDARD IDLE dump"	
	echo " ==> Dump operation is requested"
	echo " Parent dumpdir path is = $DUMPDIR"
	echo " VM dump data path is = $DUMPDIR/$dump_subdir"
fi

if [ $CONCURRENT -eq 1 ]; then
	operation_type="CONCURRENT dump"	
	echo " ==> A dump of type CONCURRENT is requested"
fi

# At this point in the script, all we have to do is dump or concurrent dump.
# We are not checking the $DUMP varable because there is no other decision to make.
# Proceeding with dump operations...

# Make sure that dumpdir directory exists
if ! [ -d $DUMPDIR/ ]; then
	echo "$date_time : ERROR ABORT $script_name - $DUMPDIR does not exist!!"
	exit
fi

# If the lockfile file exists, then we have not completed a previous  backup operation.
# The backuppc server may still be collecting the dump from this host.
# The previous dump attempt may have prematurely failed.
# Do not start another dump if one is already in progress and/or the backuppc server has not yet invoked the dump cleanup script.
if [ -e $DUMPDIR/${lockfile}  ]; then
	echo " WARNING $script_name - WARNING backup and/or dump may already being runing."
	echo " =====> detected lockfile at $DUMPDIR/$lockfile <===== "
	echo " Dump may already be running. Use --clean option first to remove the lock and try again."
	exit
else
	# Create the lockfile and begin...
	echo "$date_time dump processing started" > ${DUMPDIR}/${lockfile}
	echo "$date_time : $DUMPDIR/$lockfile created, proceeding with dump operation..."
fi

# Create the vm dump subdirectory if it does not already exist.
mkdir -p "$DUMPDIR/$dump_subdir"

# Use virsh to get an array of running VMs on the hypervisor.
# We want only the names of the VMs that are in the running state.
vms_running=($(virsh list --state-running --name))

# Pause each of the running VMs to ready them for the dump operation as perscribed by the "concurrent" option.
# Dump each of the previously running VMs
if [ ${#vms_running[@]} -eq 0 ]; then
	echo "$date_time : no running VMs detected"
else
	# Suspend all running VMs only if we are not dumping concurrently. 
	if [ $CONCURRENT -eq 0 ]; then
		for i in "${vms_running[@]}"; do
			date_time=$(date)
			echo "$date_time : suspending VM  $i"
			virsh suspend "$i"
		done
	fi

	# Dump VMs by creation of a temporary clone.
	for i in "${vms_running[@]}"
	do
		# If concurrent, then suspend the respective VM
		if [ $CONCURRENT -eq 1 ]; then
			date_time=$(date)
			echo "$date_time : concurrently suspending VM  $i"
			virsh suspend "$i"
		fi

		# Perform the VM clone dump...
		create_and_dump_temporary_clone "$i"

		# If concurrent, then resume the respective VM
		if [ $CONCURRENT -eq 1 ]; then
			date_time=$(date)
			echo "$date_time : concurrently resuming VM  $i"
			virsh resume "$i"
		fi
	done
fi

# Now we deal with the remaining VMs. The previously shutoff, or inactive ones.
vms_inactive=($(virsh list --inactive --name))
if [ ${#vms_inactive[@]} -eq 0 ]; then
	echo "$date_time : no inactive VMs detected"
else
	# Dump VMs by creation of a temporary clone.
	for i in "${vms_inactive[@]}"
	do
		create_and_dump_temporary_clone "$i"
	done
fi

if [ $CONCURRENT -eq 0 ]; then
	# Finally we resume all of the previously running VMs, to restore them to originally running state after all of the dumps have completed.
	if [ ${#vms_running[@]} -eq 0 ]; then
		echo "$date_time : There are no running VMs to resume"
	else
		for i in "${vms_running[@]}"
		do
			date_time=$(date)
			echo "$date_time : resuming VM $i"
			virsh resume "$i"
		done
	fi
fi

	print_run_time

date_time=$(date)
# We are done for now. Exit
echo "$date_time : **************** COMPLETED $script_name"
exit

