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
	if [ "${programPath:0:2}" = "./" ]; then
		programPath="`pwd`${programPath#.}"
	elif [ "${programPath:0:1}" != "/" ]; then
		programPath="`pwd`/$programPath"
	fi
	topDir=`dirname "$programPath"`

# Driver name
	drivername="TM/BA Series Printer Driver for Linux"
	if [ -f $topDir/.install/pkgid ]; then
		package_name=`cat $topDir/.install/pkgid`
	else
		package_name="tmx-cups-2.0.x.x"
	fi
	driverver="Ver.${package_name#tmx-cups-}"
	if [ `expr ${driverver:4:1} \< 0` -eq 1 -o `expr ${driverver:4:1} \> 9` -eq 1 ]; then
		driverver="Ver.${package_name#tmx-cups-*-}"
	fi
	backend_name="tmbaprn"

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

## show incompatible packages to be uninstalled
##
show_incompatible ()
{
if test -n "$uninstall_packages"; then
cat <<EOF
Before the installation, package:"${incmptbl_package}" must be uninstalled.
  Packages to be uninstalled:
    $incmptbl_tmcups
    $incmptbl_backend
EOF
if test -n "$epuras"; then
cat <<EOF2
    $epuras
EOF2
fi
if test -n "$incmptbl_ppd"; then
cat <<EOF3
  PPD files to be uninstalled:
    $incmptbl_ppd
EOF3
fi
cat <<EOF4

EOF4
fi
}

## show usage
##
usage ()
{
cat <<EOF
Driver package installer for "${drivername}"
  Target package: ${package_name}

usage: `basename $0` [option]

  option:
	-t | --test    Test mode          (do not install)
	-h | --help    Show help message  (do not install)
	-u | --usage   Show usage message (do not install)
	-v | --version Show version info  (do not install)

EOF
if test "$1" != "0"; then
	show_incompatible
fi
}

## wait Enter key pressed
##
press_enter_key ()
{
	echo -n "Press the Enter key."
	read REPLY
}

## check command validity
##
check_command ()
{
	which "$1" 1>/dev/null 2>&1
}

## check for tmx-cups* packages
##
## Pre-condition:
##   ${package}=seaching package prefix, including "*"
##   $cmd=package management command
## OnReturn:
##   The following variables are set:
##     uninstaller (if any package must be uninstalled)
##     uninstall_packages
##     incmptbl_package
##     incmptbl_tmcups
##     incmptbl_backend
##     incmptbl_bke_sfx
##     incmptbl_ppd
check_tmx_pkgs ()
{
	# check tmx-cups filter
	tmx_flt_name=""
	tmx_flt_ver=""
	tmx_flt_diff=0
	if test "rpm" = "$cmd"; then
		pkginfo=`$cmd -aq "${package}" 2>/dev/null|grep -v backend`
	else
		pkginfo=`$cmd -l "${package}" 2>/dev/null|grep -e ^[ip]i|grep -v backend`
	fi
	if test $? -eq 0; then
# name matching filter found
		if test "rpm" = "$cmd"; then
# for rpm, pkginfo must be 'package-version' form
			pkg_ver="${pkginfo#$package-}"
			pkg_name="${pkginfo%-$pkg_ver}"
			pkg_ver="${pkg_ver%-*.rpm}"
		else
# for dpkg, pkginfo must be 'ii package version description' form
			pkg_name=`echo $pkginfo|cut -d " " -f 2`
			pkg_ver=`echo $pkginfo|cut -d " " -f 3`
		fi
		tmx_flt_name=$pkg_name
		tmx_flt_ver=$pkg_ver
		if test "tmx-cups" != "${pkg_name}"; then
			tmx_flt_diff=1
    	fi
	fi
# check tmx-cups backend
	tmx_bke_name=""
	tmx_bke_ver=""
	tmx_bke_diff=0
	if test "rpm" = "$cmd"; then
		pkginfo=`$cmd -aq "${package}" 2>/dev/null|grep backend`
	else
		pkginfo=`$cmd -l "${package}" 2>/dev/null|grep -e ^[ip]i|grep backend`
	fi
	if test $? -eq 0; then
# name matching backend found
		if test "rpm" = "$cmd"; then
# for rpm, pkginfo must be 'package-version' form
			pkg_ver="${pkginfo#$package-backend*-}"
			pkg_name="${pkginfo%-$pkg_ver}"
			pkg_ver="${pkg_ver%-*.rpm}"
		else
# for dpkg, pkginfo must be 'ii package version description' form
			pkg_name=`echo $pkginfo|cut -d " " -f 2`
			pkg_ver=`echo $pkginfo|cut -d " " -f 3`
		fi
		tmx_bke_name=$pkg_name
		tmx_bke_ver=$pkg_ver
		if test "tmx-cups-backend" != "${pkg_name}"; then
			tmx_bke_diff=1
		fi
	fi
	if test $tmx_flt_diff -ne 0 -o $tmx_bke_diff -ne 0; then
		uninstaller="$cmd"
		$pkg_ver="2.0.x.x"
		incmptbl_tmcups="$tmx_flt_name-$tmx_flt_ver"
		incmptbl_backend="$tmx_bke_name-$tmx_bke_ver"
		incmptbl_bke_sfx="${tmx_bke_name#tmx-cups-backend}"
		incmptbl_package="$tmx_flt_name-$pkg_ver"
		uninstall_packages="$uninstall_packages
    $tmx_flt_name
    $tmx_bke_name"
# set incmptbl_ppd
		if [ -d /usr/share/ppd/Epson ]; then
			incmptbl_ppd=`ls -1 /usr/share/ppd/Epson|awk '{printf "    %s\n",$0}'`
		elif [ -d /usr/share/cups/model/Epson ]; then
			incmptbl_ppd=`ls -1 /usr/share/cups/model/Epson|awk '{printf "    %s\n",$0}'`
		fi
	fi
}

## initialize part 2
##
init_2 ()
{
#
# execute simple optional action, setting TEST option flag
#
	TEST="no"
	for a in $*; do
		case "$a" in
			"-t" | "--test"    ) TEST="yes";;
			"-h" | "--help"    ) version; usage; exit 0;;
			"-u" | "--usage"   )          usage 0; exit 0;;
			"-v" | "--version" ) version;         exit 0;;
			"-d" | "--debug"   ) set -x;;
			"--"               ) break;;
			*) echo "[ERROR] Unknown option."; exit 255;;
		esac
	done

# set tgtPpdDir
	if [ -d /usr/share/ppd ]; then
		tgtPpdDir="/usr/share/ppd"
	else
		tgtPpdDir="/usr/share/cups/model"
	fi

# Change root.
	if [ 0 -ne `id -u` ]; then
		echo "Running the sudo command..."
		sudo $0 $*
		status=$?
		if [ 1 -eq ${status} ]; then
			echo ""
			echo "[ERROR] The sudo command failed."
			echo "[ERROR] Please execute the `basename $0` again after changing to the root."
			press_enter_key
		fi
		exit ${status}
	fi

# show version at first.
	version

#
# Prepare for installation
#
# check package management system.
	default_packager=""
	for cmd in rpm dpkg; do
	    check_command $cmd
	    if test $? -eq 0; then
			default_packager=$cmd
	    fi
	done
	if test -z ${default_packager}; then
	    echo "[ERROR] Fatal error."
	    press_enter_key
	    exit 255
	fi

#
# Check installed package
#
# Uninstall target (incompatible version driver packages)
	target_packages="
    tmt-cups
    tmu-cups-filter
    tmt-cups-backend
    epson-cups-escpos
    ep-escpos
    ep-core
    ep-client
"
#%  \"tmx-cups*\" removed because customized tmx-cups drivers have got
#%  the compatibility with standard tmx-cups drivers.
# Control variables to be set here:
#	uninstaller			uninstall command
#	uninstall_packages	packages to be uninstalled
#	incmptbl_package	incompatible version package name to be uninstalled
#	incmptbl_tmcups		incompatible version filter package to be uninstalled
#	incmptbl_backend	incompatible version backend package to be uninstalled
#	epuras				old version epuras packages to be uninstalled
#	incmptbl_ppd		incompatible version PPD file name to be uninstalled
	uninstaller=""
	uninstall_packages=""
	incmptbl_package="(unknown)"
	incmptbl_tmcups="(filter package not found)"
	incmptbl_backend="(backend package not found)"
	incmptbl_bke_sfx=""
	epuras=""
	incmptbl_ppd=""
	echo "Checking for incompatible packages..."
	for cmd in rpm dpkg; do
		check_command $cmd
		if test $? -eq 0; then
			if test "rpm" = "$cmd"; then
				option="-q"
			else
				option="-l"
			fi
			for package in ${target_packages}; do
				if test "\"tmx-cups*\"" = "${package}"; then
# Currently, this part NOT USED
					package="${package//\"/}"
					check_tmx_pkgs
					continue
				fi
				if test "rpm" = "$cmd"; then
					pkginfo=`$cmd ${option} ${package} 2>/dev/null`
				else
					pkginfo=`$cmd ${option} ${package} 2>/dev/null|grep -e ^[ip]i`
				fi
				if test $? -eq 0; then
					uninstaller="$cmd"
					if test "rpm" = "$cmd"; then
# for rpm, pkginfo must be 'package-version' form
						pkg_ver="${pkginfo#$package?}"
					else
# for dpkg, pkginfo must be 'ii package version description' form
						pkg_ver=`echo $pkginfo|cut -d " " -f 3`
					fi
					case "$package" in
						"tmx-cups" )
							incmptbl_tmcups="$package-$pkg_ver"
							uninstall_packages="$uninstall_packages
    $package"
							;;
						"tmx-cups-backend" )
							case "$pkg_ver" in
								"1.2.0.0-1" ) incmptbl_package="tmx-cups-2.0.0.0";;
								"1.2.1.0-1" ) incmptbl_package="tmx-cups-2.0.1.x";;
								* ) incmptbl_package="tmx-cups-2.0.x.x";;
							esac
							incmptbl_backend="$package-$pkg_ver"
							uninstall_packages="$uninstall_packages
    $package"
							;;
						"tmt-cups" )
							incmptbl_tmcups="$package-$pkg_ver"
							uninstall_packages="$uninstall_packages
    $package"
							;;
						"tmu-cups-filter" )
							incmptbl_package="tmu-cups-1.0.0.0"
							incmptbl_tmcups="$package-$pkg_ver"
							uninstall_packages="$uninstall_packages
    $package"
							;;
						"tmt-cups-backend" )
							case "$pkg_ver" in
								"1.1.0.0-1" ) incmptbl_package="tmt-cups-1.4.n.0 (n=0,1)";;
								"1.1.0.0-2" ) incmptbl_package="tmt-cups-1.4.2.0";;
								* ) incmptbl_package="tmt-cups-1.4.x.0";;
							esac
							incmptbl_backend="$package-$pkg_ver"
							uninstall_packages="$uninstall_packages
    $package"
							;;
						"epson-cups-escpos" )
							incmptbl_backend="$package-$pkg_ver"
							uninstall_packages="$uninstall_packages
    $package"
							;;
						ep-* )
							if test "(unknown)" = $incmptbl_package -a "ep-escpos" = "$package"; then
								case "$pkg_ver" in
									"2.3.2.90-1" ) incmptbl_package="tmt-cups-1.3.x.0";;
									"2.3.0.90-1" ) incmptbl_package="tmt-cups-1.2.1.0";;
									"2.0.10.6-1" | "2.0.10.5-1" ) incmptbl_package="tmt-cups-1.2.0.0";;
									"2.0.10.101-1" ) incmptbl_package="tmt-cups-1.1.0.1";;
									"2.0.10.2-1" ) incmptbl_package="tmt-cups-1.1.0.0";;
									"2.0.10.0-1" ) incmptbl_package="tmt-cups-1.0.x.0";;
								esac
							fi
							if test -n "$epuras"; then
								epuras="$epuras
    "
							fi
							epuras="$epuras$package-$pkg_ver"
							uninstall_packages="$uninstall_packages
    $package"
							;;
						* )
							;;
					esac
				fi
			done
			test -n "$uninstaller" && break
		fi
	done
	if test -z "$uninstaller"; then
		uninstaller=${default_packager}
	fi
}

## uninstall incompatible packages
##
uninstall_incompatible ()
{
#
# Uninstall incompatible TM/BA printer driver installation, if detected
#
	if test -n "$uninstall_packages"; then
		echo "Incompatible version of TM/BA printer driver found!"
		show_incompatible

# Get CUPS printers that use the driver to be uninstalled.
#   set uri prefix for the backend used
		if test -n "$epuras"; then
			uripfx="epsontm:/ESDPRT"
		else
			uripfx="${backend_name}${incmptbl_bke_sfx}:/ESDPRT"
		fi
#   use LANG=C to unify output string format
#   get the line including $uripfx from lpstat output.
#   and get the 3rd word from the line, setting it to tmprnlist
		tmprnlist=`LANG=C lpstat -t 2>/dev/null|grep "$uripfx"|cut -d " " -f 3`

# set uninstaller option.
		if test "rpm" = "${uninstaller}"; then
			if test "no" = "${TEST}"; then
			    option="-e"
			else
			    option="-e --test"
			fi
		else
			if test "no" = "${TEST}"; then
			    option="-P"
			else
			    option="--no-act -P"
			fi
		fi

		if test "no" = "${TEST}"; then
# user confirm: uninstalling the incompatible printer driver installation
			while true; do
				echo -n "Uninstall the incompatible printer driver: ${incmptbl_package}  [y/n]? "
				read a
				answer="`echo $a | tr A-Z a-z`"
				case "$answer" in
					"y" | "yes" ) break;;
					"n" | "no"  )
						echo "Uninstallation canceled."
						echo ""
						echo "You can't install new TM/BA series printer driver without uninstalling "
						echo "the incompatible version."
						press_enter_key
						exit 0;;
					* ) echo "[ERROR] Please enter \"y\" or \"n\".";;
				esac
			done

# Do uninstall.
			if test -f /var/epson/epuras/epuras.properties; then
				if test -f /tmp/epuras.properties; then
					echo "Move /tmp/epuras.properties to /tmp/epuras.properties.bak"
					mv /tmp/epuras.properties /tmp/epuras.properties.bak
				fi
				echo "Backup /var/epson/epuras/epuras.properties to /tmp/..."
				cp -p /var/epson/epuras/epuras.properties /tmp/ 
			fi
			for package in ${uninstall_packages}; do
				echo "${uninstaller} ${option} ${package}"
				${uninstaller} ${option} ${package}
				sleep ${sleep_sec}
			done
# delete PPD files (if any)
			if test -n "$incmptbl_ppd"; then
				echo "Deleting all PPD files in $tgtPpdDir/Epson..."
				rm -rf "$tgtPpdDir/Epson"
			fi
			echo ""

# preset yes
			answer="y"
			if test -n "$tmprnlist"; then
# user confirm: deleting printers that use the uninstalled TM/BA series printer driver
				while true; do
					echo -n "Delete printers that use the driver you have uninstalled ahead [y/n]? "
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
# Do uninstall test.
			echo "* default_packager=${default_packager}"
			echo "* uninstaller=${uninstaller} ${option}"
			echo "* packages to be uninstalled: ${uninstall_packages}"
			echo "* Uninstall test:"
			${uninstaller} ${option} ${uninstall_packages}
			if test -n "$tmprnlist"; then
# Show recommendation message
				echo "Desirable to delete the printers that use the incompatible driver."
			fi
# force to yes on test mode.
			answer="y"
		fi

		if test "y" = "${answer}"; then
# Delete CUPS printers that use the uninstalled driver.
# delete all printers in tmprnlist
			if test -n "$tmprnlist"; then
				for tmprn in $tmprnlist; do
# remove the last ':'
					tmprn=${tmprn%:}
# delete tmprn
					if test "no" = "${TEST}"; then
						echo "Deleting printer: $tmprn"
						lpadmin -x $tmprn
					else
# only display message on test mode
						echo "  Desirable to delete the printer: $tmprn."
					fi
				done
			else
				echo "No printer using the incompatible driver."
			fi
		else
# only display message when the printer deletion cancelled
			echo "Printer deletion canceled."
		fi
		echo ""
	fi
}

## Do distribution check. (return distName)
##
checkDistribution ()
{
# check distribution
	desc=`lsb_release -d 2>/dev/null|cut -f 2`
	os=`echo $desc|awk '{print $1}'`
	ver=`lsb_release -sr 2>/dev/null|cut -d '.' -f 1,2`
	chk="SUSE Linux Enterprise Desktop"
	len=`expr length "$chk"`
	if [ "$chk" = "${desc:0:$len}" ]; then
		os="SLED"
	fi
	chk="Red Hat Enterprise Linux"
	len=`expr length "$chk"`
	if [ "$chk" = "${desc:0:$len}" ]; then
		os="RHEL"
	fi
	if [ -z "$os" ]; then
		cat /etc/*release | grep -q "openSUSE" > /dev/null 2>&1
		if [ 0 -eq $? ]; then
			os="openSUSE"
			ver=`cat /etc/*release | head -1 | awk '{print $2}'`
		else
			cat /etc/*release | grep "_ID=" | grep -q "Ubuntu" > /dev/null 2>&1
			if [ 0 -eq $? ]; then
				os="Ubuntu"
				ver=`cat /etc/*release | grep DISTRIB_RELEASE=`
				ver="${ver#DISTRIB_RELEASE=}"
			else
				cat /etc/*release | head -1 | grep -q "Fedora" > /dev/null 2>&1
				if [ 0 -eq $? ]; then
					os="Fedora"
					ver=`cat /etc/*release | head -1 | awk '{print $3}'`
				else
					cat /etc/*release | head -1 | grep -q "Debian" > /dev/null 2>&1
					if [ 0 -eq $? ]; then
						os="Debian"
						ver=`cat /etc/*release | head -1 | awk '{print $3}'`
					else
						cat /etc/*release | head -1 | grep -q "CentOS" > /dev/null 2>&1
						if [ 0 -eq $? ]; then
							os="CentOS"
							ver=`cat /etc/*release | head -1 | awk '{print $3}'`
							if [ `expr ${ver:0:1} \< 0` -eq 1 -o `expr ${ver:0:1} \> 9` -eq 1 ]; then
								ver=`cat /etc/*release | head -1 | awk '{print $4}'`
							fi
							ver=`echo $ver|cut -d '.' -f 1,2`
						else
							cat /etc/*release | head -1 | grep -q "Red Hat Enterprise Linux" > /dev/null 2>&1
							if [ 0 -eq $? ]; then
								os="RHEL"
								ver=`cat /etc/*release | head -1 | awk '{print $7}'`
							else
								os="Unknown"
							fi
						fi
					fi
				fi
			fi
		fi
	fi
	distName="$os-$ver"
}

## The Architecture is checked.  (return archName)
##
checkArchitecture ()
{
	#Select Architecte
	checkArchName=`uname -m`

	case "$checkArchName" in
		"i386" | "i486")
			archName="i386"
			;;
		"i586" | "i686")
			archName="i586"
			;;
		"amd64" | "x86_64")
			archName="x86_64"
			;;
		*)
			archName=""
			;;
	esac
}


## Packages installation ($1=PackageListFile)
##
packageInstall ()
{
# Get list filename.
	list="$1"
	status=0

	[ "yes" = "$TEST" ] && echo "* Package list file = ${list}"

	if [ -f "${list}" ]; then

		packageType=`basename ${list} | sed -e 's,\.list$,,' | awk -F- '{ print $4 }'`

		case "${packageType}" in
			"RPM")
				installCommand="rpm -U"
				[ "Fedora" = $os ] && installCommand="rpm -U --replacefiles"
				[ "yes" = "$TEST" ] && installCommand="rpm -U --test"
				;;
			"DEB")
				installCommand="dpkg -i --no-force-downgrade"
				[ "yes" = "$TEST" ] && installCommand="dpkg --no-act -i --no-force-downgrade"
				;;
			*)
				echo "[ERROR] Fatal error."
				echo "[ERROR] Package installation failed."
				press_enter_key
				exit 255
				;;
		esac

		cd $topDir

		if [ "yes" = "${TEST}" ]; then
			echo "* Target packages:"
			ls -1 `cat ${list}`
			echo "* Install test:"
			$installCommand `cat ${list}`
		else
			for file in `cat ${list}`; do
				tmperr=`mktemp`
				$installCommand "$topDir/$file" 2> ${tmperr}
				rc=$?
				if [ ${status} -eq 0 ]; then
					status=${rc}
				fi
# show error except for SELinux related
				cat ${tmperr} | grep -vE "sepol|semodule|semanage"
				rm ${tmperr}
			done
		fi

# install SELinux policy module (if needed)
		install_policy_module
# install optional files
		install_opt_files

	else
		echo "[ERROR] cannot access ${list}: No such file."
		echo "[ERROR] Package installation failed."
		press_enter_key
		exit 255
	fi
	return ${status}
}

## get splitted installation package list name (return splitListName)
##
get_splitListName ()
{
	list=`basename $1 | sed -e 's,\.list$,,'`

	dist=`echo ${list} | awk -F- '{ print $1 }' | sed -e 's,_, ,g'`
	rel=`echo ${list} | awk -F- '{ print $2 }'`
	arch=`echo ${list} | awk -F- '{ print $3 }'`
#	pkg=`echo ${list} | awk -F- '{ print $4 }'`

	case "$arch" in
		"i386" | "i486" | "i586" | "i686")
			displayArch="x86(32bit)"
			;;
		"amd64" | "x86_64")
			displayArch="x86_64(64bit)"
			;;
		*)
			displayArch="$arch"
			;;
	esac

	splitListName="${dist} ${rel} ${displayArch}"
}

## User select number (255 is error)
##
get_number ()
{
	read line

	n=`expr "${line}" \* 1 2>/dev/null`
	[ $? -ge 2 ] && return 255

	if [ $n -lt 0 ]; then
		return 255
	fi

	return $n
}

## select distribution for manual install
##
select_list_file ()
{
	number=0
	endStrings=""

	while true; do
		echo ""
		echo "Please select your distribution."

		endStrings="Select number [0(cancel)"

		count=0
		for list in `ls -1 $topDir/.install/*.list | LC_ALL=C sort`; do

			get_splitListName "$list"

			count=`expr $count + 1`

			echo "$count.${splitListName}"

			endStrings="$endStrings/$count"

		done

		echo -n "${endStrings}]? "

		get_number
		number=$?

		if [ 0 -eq $number ]; then
			echo "Installation canceled."
			press_enter_key
			exit 0
		fi

		if [ ${number} -le ${count} ]; then

			i=0
			selectedListFile=""
			for list in `ls -1 $topDir/.install/*.list | LC_ALL=C sort`; do

				i=`expr $i + 1`

				if [ ${number} -eq $i ]; then
					selectedListFile="$list"
					break;
				fi
			done

			if [ -n "${selectedListFile}" ]; then
				break
			fi
		fi

		echo "[ERROR] Please input a correct number."
	done
}

## install SELinux policy module (if needed)
##
install_policy_module ()
{
	if [ -x /usr/sbin/semodule ]; then
		if [ -f "${topDir}/backend/${backend_name}.${os}.${ver}.pp" ]; then
			ppfile="${topDir}/backend/${backend_name}.${os}.${ver}.pp"
		elif [ -f "${topDir}/backend/${backend_name}.${os}.${ver%.*}.pp" ]; then
			ppfile="${topDir}/backend/${backend_name}.${os}.${ver%.*}.pp"
		elif [ -f "${topDir}/backend/${backend_name}.${os}.pp" ]; then
			ppfile="${topDir}/backend/${backend_name}.${os}.pp"
		else
			return
		fi
		modver=`semodule -l | grep ${backend_name} | awk '{print $2}'`
		if [ -n "${modver}" ]; then
# ${backend_name} policy module found
			grep ${modver} ${ppfile} > /dev/null 2>&1
			if [ $? -ne 0 ]; then
# if NOT the same version as ${ppfile}, should install ${ppfile}
				modver=""
			fi
		fi
		if [ -n "${modver}" ]; then
			echo ""
			echo "        SELinux policy module ${backend_name} ${modver} is already installed."
		elif [ "yes" = "${TEST}" ]; then
			echo "* The SELinux policy module file will be installed:"
			echo "  ${ppfile}"
		else
			echo ""
			echo "Installing SELinux policy module..."
			semodule -u "${ppfile}"
		fi
	fi
}

## install optional files
##
install_opt_files ()
{
	if [ -d /usr/share/ppd ]; then
		tgtDir="/usr/share/ppd"
	else
		tgtDir="/usr/share/cups/model"
	fi
	if [ "yes" = "${TEST}" ]; then
		echo "* The following PPD files will be copied to ${tgtDir}/Epson:"
		ls "${topDir}/ppd"
		if [ -x "${topDir}/setupbt" ]; then
			echo "* The shell script setupbt will be copied to /usr/sbin/."
		fi
	else
		if [ ! -d "${tgtDir}/Epson" ]; then
			echo "Making directory...: ${tgtDir}/Epson"
			mkdir -p "${tgtDir}/Epson"
		fi
		if [ -d "${tgtDir}/Epson" ]; then
			echo "Copying PPD files to ${tgtDir}/Epson..."
			cp -p ${topDir}/ppd/tm-* ${tgtDir}/Epson/
			chmod -f 644 ${tgtDir}/Epson/*
		fi
		if [ -x "${topDir}/setupbt" ]; then
			echo "Copying setupbt script file to /usr/sbin/..."
			cp -p -f "${topDir}/setupbt" /usr/sbin/
		fi
	fi
}

#
# MAIN
#

#
# initialization
#
init
init_2 $*
uninstall_incompatible

#
# Start installation
#

#check Distribution.
distName=
checkDistribution
[ "yes" = "$TEST" ] && echo "* This distribution is \"${distName}\""

#check Architectur
archName=
checkArchitecture
[ "yes" = "$TEST" ] && echo "* Machine Architecture is \"${archName}\""

#get package list file name
targetFile=`ls -1 $topDir/.install/$distName-$archName-*.list 2> /dev/null`

if [ -n "$targetFile" -a -f "$targetFile" ]; then

	while true; do

		get_splitListName "${targetFile}"

		echo -n "Install ${package_name} into ${splitListName} [y/n]? "
		read a

		answer="`echo $a | tr A-Z a-z`"

		case "$answer" in
			"y" | "yes" )
# take default action
				break
				;;
			"n" | "no"  )
# manual installation, selecting distribution
				select_list_file
				targetFile="${selectedListFile}"
				break
				;;
			* )
				echo "[ERROR] Please enter \"y\" or \"n\"."
				;;
		esac
	done
else
	select_list_file
	targetFile="${selectedListFile}"
fi

#Do Packages installation
packageInstall ${targetFile}

#Show finishing message and wait Enter Key
echo ""
if test "no" == "${TEST}"; then
	echo "*** The installation finished. ***"
else
	echo "*** The installation test finished. ***"
fi
echo ""
press_enter_key

# end of file
