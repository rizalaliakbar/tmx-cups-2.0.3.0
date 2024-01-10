#!/bin/bash

## Subroutines
##

## initilaize
##
init ()
{
	LC_ALL=C
	export LC_ALL

# Set top directory.
	programPath=`which $0`
	topDir=`dirname "$programPath"`

# Driver name
	drivername="TM/BA Series Printer Driver for Linux"
	if [ -f $topDir/.install/pkgid ]; then
		package_name=`cat $topDir/.install/pkgid`
	else
		package_name="tmx-cups-2.0.x.x"
	fi
	driverver="Ver.${package_name#tmx-cups*-}"
	backend_name="tmbaprn"

# Uninstall target
	target_packages="
    tmx-cups
    tmx-cups-backend
    EPSON-Port-Communication-Service
"

# Interval (sec)
	sleep_sec=0
}

## show version
##
version ()
{
    cat <<EOF
`basename $0`  for "${drivername}"  ${driverver}
  Copyright (C) Seiko Epson Corporation 2010-2016. All rights reserved.

EOF
}

press_enter_key ()
{
    echo -n "Press the Enter key."
    read REPLY
}

## show usage
##
usage ()
{
cat <<EOF

Package uninstaller for "${drivername}"
Target Package:${package_name}

usage: `basename $0` [option]

  option:
	-t | --test    Test mode          (do not uninstall)
	-h | --help    Show help message  (do not uninstall)
	-u | --usage   Show usage message (do not uninstall)
	-v | --version Show version info  (do not uninstall)

uninstalled packages:  ${target_packages}

EOF
}

## check command validity
##
check_command ()
{
    which "$1" 1>/dev/null 2>&1
}


## initialize part 2
##
init_2 ()
{
# execute simple optional action, setting TEST option flag
	TEST="no"
	for a in $*; do
	    case "$a" in
			"-t" | "--test"    ) TEST="yes";;
			"-h" | "--help"    ) version; usage; exit 0;;
			"-u" | "--usage"   )           usage; exit 0;;
			"-v" | "--version" ) version;         exit 0;;
			"-d" | "--debug"   ) set -x;;
			"--") break;;
			*) echo "[ERROR] Unknown option."; exit 255;;
	    esac
	done

# check package management system.
	default_packager=""
	for cmd in rpm dpkg; do
	    check_command $cmd
	    if [ $? -eq 0 ]; then
			default_packager=$cmd
	    fi
	done
	if [ -z ${default_packager} ]; then
	    echo "[ERROR] Fatal error."
	    press_enter_key
	    exit 255
	fi

# check installed package.
	uninstaller=""
	for cmd in rpm dpkg; do
	    check_command $cmd
	    if [ $? -eq 0 ]; then
			if [ "rpm" = "$cmd" ]; then
				option="-q"
			else
				option="-l"
			fi
			for package in ${target_packages}; do
				$cmd ${option} ${package} 1>/dev/null 2>&1
				if [ $? -eq 0 ]; then
					uninstaller=$cmd
					break
				fi
			done
			test -n "${uninstaller}" && break
	    fi
	done

	if [ -z "${uninstaller}" ]; then
	    uninstaller=${default_packager}
	fi

# Change root.
	if [ 0 -ne `id -u` ]; then
	    echo "Running the sudo command..."
	    sudo $0 $*
	    result=$?
	    if [ 1 -eq $result ]; then
			echo ""
			echo "[ERROR] The sudo command failed."
			echo "[ERROR] Please execute the `basename $0` again after changing to the root."
			press_enter_key
	    fi
	    exit $result
	fi
}

## Packages uninstallation
##
packageUninstall ()
{
# user confirm.
	if [ "no" = "${TEST}" ]; then
		while true; do
			echo -n "Uninstall ${package_name}  [y/n]? "
			read a
			answer="`echo $a | tr A-Z a-z`"
			case "$answer" in
				"y" | "yes" ) break;;
				"n" | "no" )
					echo "Uninstallation canceled."
					press_enter_key
					exit 0;;
				* ) echo "[ERROR] Please enter \"y\" or \"n\".";;
			esac
	    done
	fi

# uninstall SELinux policy module
	uninstall_policy_module

# set uninstaller option.
	if [ "rpm" = "${uninstaller}" ]; then
	    if [ "no" = "${TEST}" ]; then
	        option="-e"
	    else
	        option="-e --test"
	    fi
	else
	    if [ "no" = "${TEST}" ]; then
	        option="-P"
	    else
	        option="--no-act -P"
	    fi
	fi

# get list of printers that use TM/BA series printer driver being uninstalled
#   use LANG=C to unify output string format
#   get the line including "${backend_name}:/ESDPRT" from lpstat output.
#   and get the 3rd word from the line, setting it to tmprnlist
	tmprnlist=`LANG=C lpstat -t 2>/dev/null|grep "${backend_name}:/ESDPRT"|cut -d " " -f 3`

# preset answer to yes for deleting printer(s).
	answer="y"
# Do uninstall.
	if [ "no" = "${TEST}" ]; then
# uninstall target_packages
	    for package in ${target_packages}; do
			echo "${uninstaller} ${option} ${package}"
			tmperr=`mktemp`
			${uninstaller} ${option} ${package} 2> ${tmperr}
# show error except for SELinux related
			cat ${tmperr} | grep -vE "semodule|semanage"
			rm ${tmperr}
			sleep ${sleep_sec}
	    done
# user confirm: deleting printers that use the uninstalled TM/BA series printer driver
		if [ -n "$tmprnlist" ]; then
			echo ""
			echo "Printer(s) using the uninstalled driver:"
			echo "$tmprnlist"
# get answer
			while true; do
				echo -n "Delete the enumerated printer(s) [y/n]? "
				read a
				answer="`echo $a | tr A-Z a-z`"
				case "$answer" in
					"y" | "yes" ) break;;
					"n" | "no"  ) answer="n"; break;;
					*         ) echo "[ERROR] Please enter \"y\" or \"n\".";;
				esac
			done
		fi
	else
# test mode; only display messages
		echo "* default_packager=${default_packager}"
		echo "* uninstaller=${uninstaller} ${option}"
	    echo "* Target packages: ${target_packages}"
	    echo "* Uninstall test:"
	    ${uninstaller} ${option} ${target_packages}
# Show recommendation message
		echo "Desirable to delete the printers that use the driver to be uninstalled."
	fi

	if [ "y" = "${answer}" ]; then
# Delete CUPS printers that use the uninstalled driver.
		if [ -n "$tmprnlist" ]; then
# delete all printers in tmprnlist
			for tmprn in $tmprnlist; do
# remove the last ':'
				tmprn=${tmprn%:}
# delete tmprn
				if [ "no" = "${TEST}" ]; then
					echo "Deleting printer: $tmprn"
					lpadmin -x $tmprn
				else
# only display message on test mode
					echo "  Going to delete $tmprn."
				fi
			done
		else
# printer that uses the driver being uninstalled not found
			echo "There is no printer to delete."
		fi
	else
# only display message when the printer deletion cancelled
		echo "Printer deletion canceled."
	fi
}


## uninstall optional files
##
uninstall_opt_files ()
{
# Deleting PPD files from CUPS database
	if [ -d /usr/share/ppd/Epson ]; then
		tgtDir="/usr/share/ppd"
	else
		tgtDir="/usr/share/cups/model"
	fi
# Bluetooth support files also deleted (if any)
	rfcommconf="/etc/bluetooth/rfcomm.conf"
	rclocal="/etc/rc.local"
	if [ ! -f ${rclocal} ]; then
		if [ -f "/etc/init.d/boot.local" ]; then
			rclocal="/etc/init.d/boot.local"
		fi
	fi
	if [ "no" = "${TEST}" ]; then
		deleted=0
		find "${tgtDir}/Epson/" -name "tm-*rastertotmt.ppd*" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
# PPD file (rastertotmt) found
			deleted=1
			echo "Deleting PPD files..."
			find "${tgtDir}/Epson/" -name "tm-*rastertotmt.ppd*" -exec rm -f  \{\} \; >/dev/null 2>&1
		fi
		find "${tgtDir}/Epson/" -name "tm-*rastertotmu.ppd*" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
# PPD file (rastertotmu) found
			if [ $deleted -eq 0 ]; then
				deleted=1
				echo "Deleting PPD files..."
			fi
			find "${tgtDir}/Epson/" -name "tm-*rastertotmu.ppd*" -exec rm -f  \{\} \; >/dev/null 2>&1
		fi
		if [ $deleted -eq 1 ]; then
			ls ${tgtDir}/Epson/* >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				echo "Removing directory...: ${tgtDir}/Epson"
				rmdir "${tgtDir}/Epson"
			fi
		else
# PPD file for TM-CUPS not found
			echo "There is no PPD file to delete."
		fi
		if [ -f /usr/sbin/setupbt ]; then
			echo "Removing Bluetooth port support files..."
			rm -f /usr/sbin/setupbt
			mv -f "${rfcommconf}.org" "${rfcommconf}"
			rm -f "${rfcommconf}.bak"
			mv -f "${rclocal}.org" "${rclocal}"
			rm -f "${rclocal}.bak"		
		fi
	else
		echo "* The following files will be deleted:"
		ls ${tgtDir}/Epson/tm-*rastertotmt.ppd* 2>/dev/null
		ls ${tgtDir}/Epson/tm-*rastertotmu.ppd* 2>/dev/null
		if [ -f /usr/sbin/setupbt ]; then
			echo "/usr/sbin/setupbt"
			echo "* The following files will be recovered:"
			echo "${rfcommconf}"
			echo "${rclocal}"
		fi
	fi
}

## uninstall SELinux policy module (if needed)
##
uninstall_policy_module ()
{
# Removing SELinux policy module
	if [ -x /usr/sbin/semodule ]; then
		if [ "no" = "${TEST}" ]; then
			echo "Removing SELinux policy module...: ${backend_name}"
			semodule -r ${backend_name}
		else
			echo "* SELinux policy module ${backend_name} will be removed."
		fi
	fi
}

#
# MAIN
#

# initialization
init
init_2 $*

# Do Packages uninstallation
packageUninstall

# uninstall optional files
uninstall_opt_files

echo ""
if [ "no" = "${TEST}" ]; then
	echo "*** The uninstallation finished. ***"
else
	echo "*** The uninstallation test finished. ***"
fi
echo ""
press_enter_key

# end of file
