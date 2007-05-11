#!/usr/local/bin/perl
# Build an RPM file for openlinux

if (-r "/usr/src/OpenLinux") {
        $base_dir = "/usr/src/OpenLinux";
        }
else {
        $base_dir = "/usr/src/redhat";
        }
$spec_dir = "$base_dir/SPECS";
$source_dir = "$base_dir/SOURCES";
$rpms_dir = "$base_dir/RPMS/noarch";
$srpms_dir = "$base_dir/SRPMS";

$ver = $ARGV[0] || die "usage: makerpm.pl <version> [release]";
$rel = $ARGV[1] || "1";

$oscheck = <<EOF;
if (-r "/etc/.issue") {
	\$etc_issue = `cat /etc/.issue`;
	}
elsif (-r "/etc/issue") {
	\$etc_issue = `cat /etc/issue`;
	}
\$uname = `uname -a`;
EOF
open(OS, "os_list.txt");
while(<OS>) {
	chop;
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t*(.*)$/ && $5) {
		$if = $count++ == 0 ? "if" : "elsif";
		$oscheck .= "$if ($5) {\n".
			    "	print \"oscheck='$1'\\n\";\n".
			    "	}\n";
		}
	}
close(OS);
$oscheck =~ s/\\/\\\\/g;
$oscheck =~ s/`/\\`/g;
$oscheck =~ s/\$/\\\$/g;

open(TEMP, "maketemp.pl");
while(<TEMP>) {
	$maketemp .= $_;
	}
close(TEMP);
$maketemp =~ s/\\/\\\\/g;
$maketemp =~ s/`/\\`/g;
$maketemp =~ s/\$/\\\$/g;

system("cp tarballs/usermin-$ver.tar.gz $source_dir");
open(SPEC, ">$spec_dir/usermin-$ver.spec");
print SPEC <<EOF;
#%define BuildRoot /tmp/%{name}-%{version}
%define __spec_install_post %{nil}

Summary: A web-based user account administration interface
Name: usermin
Version: $ver
Release: $rel
Provides: %{name}-%{version}
PreReq: /bin/sh /usr/bin/perl /bin/rm
Requires: /bin/sh /usr/bin/perl /bin/rm
Copyright: Freeware
Group: System/Tools
Source: http://www.webmin.com/download/%{name}-%{version}.tar.gz
Vendor: Jamie Cameron
BuildRoot: /tmp/%{name}-%{version}
BuildArchitectures: noarch
AutoReq: 0
%description
A web-based user account administration interface for Unix systems.

After installation, enter the URL http://localhost:20000/ into your
browser and login as any user on your system.

%prep
%setup -q

%build
(find . -name '*.cgi' ; find . -name '*.pl') | perl perlpath.pl /usr/bin/perl -
rm -f mount/freebsd-mounts-*
rm -f mount/openbsd-mounts-*
chmod -R og-w .

%install
mkdir -p %{buildroot}/usr/libexec/usermin
mkdir -p %{buildroot}/etc/sysconfig/daemons
mkdir -p %{buildroot}/etc/rc.d/{rc0.d,rc1.d,rc2.d,rc3.d,rc5.d,rc6.d}
mkdir -p %{buildroot}/etc/init.d
mkdir -p %{buildroot}/etc/pam.d
cp -rp * %{buildroot}/usr/libexec/usermin
cp usermin-daemon %{buildroot}/etc/sysconfig/daemons/usermin
cp usermin-init %{buildroot}/etc/init.d/usermin
cp usermin-pam %{buildroot}/etc/pam.d/usermin
ln -s /etc/init.d/usermin %{buildroot}/etc/rc.d/rc2.d/S99usermin
ln -s /etc/init.d/usermin %{buildroot}/etc/rc.d/rc3.d/S99usermin
ln -s /etc/init.d/usermin %{buildroot}/etc/rc.d/rc5.d/S99usermin
ln -s /etc/init.d/usermin %{buildroot}/etc/rc.d/rc0.d/K10usermin
ln -s /etc/init.d/usermin %{buildroot}/etc/rc.d/rc1.d/K10usermin
ln -s /etc/init.d/usermin %{buildroot}/etc/rc.d/rc6.d/K10usermin
echo rpm >%{buildroot}/usr/libexec/usermin/install-type

%clean
#%{rmDESTDIR}
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(-,root,root)
/usr/libexec/usermin
%config /etc/sysconfig/daemons/usermin
/etc/init.d/usermin
/etc/rc.d/rc2.d/S99usermin
/etc/rc.d/rc3.d/S99usermin
/etc/rc.d/rc5.d/S99usermin
/etc/rc.d/rc0.d/K10usermin
/etc/rc.d/rc1.d/K10usermin
/etc/rc.d/rc6.d/K10usermin
%config /etc/pam.d/usermin

%pre
perl <<EOD;
$maketemp
EOD
if [ "\$?" != "0" ]; then
	echo "Failed to create or check temp files directory /tmp/.webmin"
	exit 1
fi
perl >/tmp/.webmin/\$\$.check <<EOD;
$oscheck
EOD
. /tmp/.webmin/\$\$.check
rm -f /tmp/.webmin/\$\$.check
if [ ! -r /etc/usermin/config ]; then
	if [ "\$oscheck" = "" ]; then
		echo Unable to identify operating system
		exit 2
	fi
	echo Operating system is \$oscheck
	if [ "\$USERMIN_PORT\" != \"\" ]; then
		port=\$USERMIN_PORT
	else
		port=20000
	fi
	perl -e 'use Socket; socket(FOO, PF_INET, SOCK_STREAM, getprotobyname("tcp")); setsockopt(FOO, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)); bind(FOO, pack_sockaddr_in(\$ARGV[0], INADDR_ANY)) || exit(1); exit(0);' \$port
	if [ "\$?" != "0" ]; then
		echo Port \$port is already in use
		exit 3
	fi
fi

%post
inetd=`grep "^inetd=" /etc/usermin/miniserv.conf 2>/dev/null | sed -e 's/inetd=//g'`
if [ "\$1" != 1 ]; then
	# Upgrading the RPM, so stop the old usermin properly
	if [ "$inetd" != "1" ]; then
		/etc/init.d/usermin stop >/dev/null 2>&1
	fi
fi
cd /usr/libexec/usermin
config_dir=/etc/usermin
var_dir=/var/usermin
perl=/usr/bin/perl
autoos=3
if [ "\$USERMIN_PORT\" != \"\" ]; then
	port=\$USERMIN_PORT
else
	port=20000
fi
host=`hostname`
ssl=1
atboot=1
nochown=1
autothird=1
noperlpath=1
nouninstall=1
nostart=1
export config_dir var_dir perl autoos port ssl nochown autothird noperlpath nouninstall nostart allow
./setup.sh >/tmp/.webmin/usermin-setup.out 2>&1
rm -f /var/lock/subsys/usermin
if [ "$inetd" != "1" ]; then
	/etc/init.d/usermin start >/dev/null 2>&1 </dev/null
fi
cat >/etc/usermin/uninstall.sh <<EOFF
#!/bin/sh
printf "Are you sure you want to uninstall Usermin? (y/n) : "
read answer
printf "\\n"
if [ "\\\$answer" = "y" ]; then
	echo "Removing usermin RPM .."
	rpm -e --nodeps usermin
	echo "Done!"
fi
EOFF
chmod +x /etc/usermin/uninstall.sh
port=`grep "^port=" /etc/usermin/miniserv.conf | sed -e 's/port=//g'`
perl -e 'use Net::SSLeay' >/dev/null 2>/dev/null
sslmode=0
if [ "\$?" = "0" ]; then
	grep ssl=1 /etc/usermin/miniserv.conf >/dev/null 2>/dev/null
	if [ "\$?" = "0" ]; then
		sslmode=1
	fi
fi
if [ "\$sslmode" = "1" ]; then
	echo "Usermin install complete. You can now login to https://\$host:\$port/"
else
	echo "Usermin install complete. You can now login to http://\$host:\$port/"
fi
echo "as any user on your system."

%preun
if [ "\$1" = 0 ]; then
	grep root=/usr/libexec/usermin /etc/usermin/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# RPM is being removed, and no new version of usermin
		# has taken it's place. Stop the server
		/etc/init.d/usermin stop >/dev/null 2>&1
		/bin/true
	fi
fi

%postun
if [ "\$1" = 0 ]; then
	grep root=/usr/libexec/usermin /etc/usermin/miniserv.conf >/dev/null 2>&1
	if [ "\$?" = 0 ]; then
		# RPM is being removed, and no new version of usermin
		# has taken it's place. Delete the config files
		rm -rf /etc/usermin /var/usermin
	fi
fi

EOF
close(SPEC);

system("rpm -ba --target=noarch $spec_dir/usermin-$ver.spec") && exit;
system("mv /usr/src/OpenLinux/RPMS/noarch/usermin-$ver-$rel.noarch.rpm rpm/usermin-$ver-$rel.noarch.rpm");
print "Moved to rpm/usermin-$ver-$rel.noarch.rpm\n";
system("mv /usr/src/OpenLinux/SRPMS/usermin-$ver-$rel.src.rpm rpm/usermin-$ver-$rel.src.rpm");
print "Moved to rpm/usermin-$ver-$rel.src.rpm\n";
system("chown jcameron: rpm/usermin-$ver-$rel.noarch.rpm rpm/usermin-$ver-$rel.src.rpm");
#system("su jcameron -c 'ssh lentor rpm --resign /usr/local/download/rpm/usermin-$ver-$rel.noarch.rpm /usr/local/download/rpm/usermin-$ver-$rel.src.rpm'");
system("rpm --resign rpm/usermin-$ver-$rel.noarch.rpm rpm/usermin-$ver-$rel.src.rpm");

