%define debug_package %{nil}
%define web_root %{_var}/www/html
%define ver 0.2.3

# If buildnum is defined, use it. Otherwise, use '1'.
%define rel %{?buildnum}%{!?buildnum:1}%{?_branding}

Summary: StackIt Cloud Formation/Puppet frontend
Name:    stack-it
Version: %ver
Release: %rel

Group:       Applications/System
License:     Commercial
URL:         http://icainformatics.com
Packager:    Frank Pickle <rpmbuild@icainformatics.com>
Vendor:      ICA Private Repository
BuildArch:   noarch
BuildRoot:   %{_tmppath}/build-root-%{name}
Source0:     %{name}.tar.gz
Requires:    httpd
Requires:    memcached
Requires:    mod_perl
Requires:    rsyslog
Requires:    perl-libapreq2
Requires:    perl-namespace-autoclean
Requires:    perl-Catalyst-Action-RenderView
Requires:    perl-Catalyst-Engine-Apache
Requires:    perl-Catalyst-Model-DBI
Requires:    perl-Catalyst-Plugin-Cache
Requires:    perl-Catalyst-Plugin-ConfigLoader
Requires:    perl-Catalyst-Plugin-StackTrace
Requires:    perl-Catalyst-Plugin-Static-Simple
Requires:    perl-Catalyst-Runtime
Requires:    perl-Catalyst-View-JSON
Requires:    perl-Catalyst-View-TT
Requires:    perl-JSON
Requires:    perl-Proc-Pidfile
Requires:    perl-YAML-Tiny
Requires:    %{name}-common
AutoReqProv: no

%description
StackIt is an ICA frontend to it's Cloud Formation and Puppet infrastructure.

# common subpackage
%package     common
Summary:     StackIt Libraries
Group:       Applications/System
Requires:    perl
Requires:    perl-Cache-Memcached
Requires:    perl-Crypt-SSLeay
Requires:    perl-DBI
Requires:    perl-DBD-MySQL
Requires:    perl-Digest-HMAC
Requires:    perl-Digest-SHA
Requires:    perl-IPC-Run
Requires:    perl-JSON-XS
Requires:    perl-libwww-perl
Requires:    perl-Moose
Requires:    perl-Template-Toolkit
Requires:    perl-TimeDate
Requires:    perl-Time-HiRes
Requires:    perl-URI
Requires:    perl-XML-Simple
AutoReqProv: no

%description common
Common Perl libraries shared between the StackIt web application and command line utilities.

# jobs-standalone subpackage
%package     jobs-standalone
Summary:     Update Scripts
Group:       Applications/System
Requires:    perl-Proc-Pidfile
Requires:    perl-Config-Simple
Requires:    %{name}-common
AutoReqProv: no

%description jobs-standalone
This package contains update scripts that do not need direct access to the StackIt database.

%pre

%prep
%setup -q -n stack-it

%build

%install
%{__rm} -rf %{buildroot}
%{__mkdir_p} -m 0755 $RPM_BUILD_ROOT%{_sysconfdir}/cron.d
%{__mkdir_p} -m 0755 $RPM_BUILD_ROOT%{_sysconfdir}/profile.d
%{__mkdir_p} -m 0755 $RPM_BUILD_ROOT%{_sysconfdir}/rsyslog.d
%{__mkdir_p} -m 0755 $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d
%{__mkdir_p} -m 0755 $RPM_BUILD_ROOT%{web_root}/%{name}
%{__mkdir_p} -m 0755 $RPM_BUILD_ROOT%{_datadir}/%{name}

%{__cp} -ap $RPM_BUILD_DIR/$RPM_PACKAGE_NAME/%{_sysconfdir} $RPM_BUILD_ROOT
%{__cp} -ap $RPM_BUILD_DIR/$RPM_PACKAGE_NAME/usr/lib/* $RPM_BUILD_ROOT%{_datadir}
%{__cp} -ap $RPM_BUILD_DIR/$RPM_PACKAGE_NAME/usr/share/stack-it/* $RPM_BUILD_ROOT%{_datadir}/%{name}
%{__cp} -ap $RPM_BUILD_DIR/$RPM_PACKAGE_NAME/www/* $RPM_BUILD_ROOT%{web_root}/%{name}

cat <<EOF > $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d/%{name}.conf
<Directory /var/www/html/stack-it>
  Options -Indexes

  <Files ~ "^\.ht">
    Order allow,deny
    Deny from all
  </Files>
</Directory>

<IfDefine DEBUG>
  PerlRequire conf/apache-db.pl
  <Location />
    PerlFixupHandler +Apache::DB
  </Location>
</IfDefine>

PerlSwitches -I/var/www/html/stack-it/lib

<Location />
  SetHandler          modperl
  PerlResponseHandler StackIt
</Location>

NameVirtualHost *:80

<VirtualHost _default_:80>
</VirtualHost>

<VirtualHost *:80>
  ServerName stack-it.example.com
  ProxyPass / http://127.0.0.1:3000/
  ProxyPassReverse / http://127.0.0.1:3000/

  <Location />
    Order allow,deny
    Allow from all
  </Location>
</VirtualHost>
EOF

%post
INSTALL_MODE=$1
ORIG_INSTALL=1
UPGRADE_INSTALL=2

. %{_sysconfdir}/profile.d/stack-it.sh

if %{_datadir}/%{name}/bin/stack-it-test-db -q 2>/dev/null; then
  %{_datadir}/%{name}/bin/stack-it-migrations-migrate --verbose --roles
else
  echo "StackIt database is not configured, skipping data load"
fi

/sbin/service rsyslog condrestart
/sbin/service httpd condrestart
/sbin/service memcached restart

%post jobs-standalone
/sbin/service rsyslog condrestart

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(0644,apache,apache,0755)
%config(noreplace) %{web_root}/%{name}/stackit.conf
%config(noreplace) %{_sysconfdir}/httpd/conf.d/%{name}.conf
%config(noreplace) %{_sysconfdir}/stack-it/database-00-development.yml
%config(noreplace) %{_sysconfdir}/profile.d/stack-it.sh

%defattr(-,root,root,-)
%{_datadir}/%{name}/bin
%{_datadir}/%{name}/data
%{_datadir}/%{name}/role_definitions
%{_datadir}/%{name}/templates
%{_datadir}/%{name}/libexec
%{_datadir}/%{name}/tools
%{_sysconfdir}/rsyslog.d/stackit.conf
%{_sysconfdir}/cron.d/stackit
%{web_root}/%{name}
%dir %{_datadir}/%{name}/jobs
%attr(0700,root,root) %{_datadir}/%{name}/bin/*.pl
%attr(0700,root,root) %{_datadir}/%{name}/jobs/scaffold.pl

%exclude %{web_root}/%{name}/Changes
%exclude %{web_root}/%{name}/t
%exclude %{web_root}/%{name}/script

%files common
%defattr(0644,root,root,0755)
%{_datadir}/perl5

%files jobs-standalone
%defattr(0644,root,root,0755)
%{_sysconfdir}/rsyslog.d/stackit.conf
%{_sysconfdir}/cron.d/stackit-jobs-standalone
%{_datadir}/%{name}/templates/rt53_change_xml.tpl
%dir %{_datadir}/%{name}/jobs
%dir %{_datadir}/%{name}/templates
%attr(0600,root,root) %{_sysconfdir}/stack-it/job.conf
%attr(0700,root,root) %{_datadir}/%{name}/jobs/scheduler.pl
%attr(0700,root,root) %{_datadir}/%{name}/jobs/dns-updater.pl
%config(noreplace) %{_sysconfdir}/stack-it/job.conf

%changelog
* Wed Oct 22 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.2.3-1
- New tag
- CONFIGMGMT-199, 194, 195, 196

* Mon Aug 11 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.2.2-1
- Added scheduling script
- Added dns update script

* Mon Jun 23 2014 Philip Garrett <philip.garrett@icainformatics.com> - 0.2.1-1
- Added profile.d and support for migrations.
- Require rsyslog

* Mon Jun 23 2014 Philip Garrett <philip.garrett@icainformatics.com> - 0.2.0-1
- New tag

* Fri Jun 20 2014 Philip Garrett <philip.garrett@icainformatics.com> - 0.1.9-1
- Prevent clobbering stackit.conf
- Added Digest::SHA dependency
- Replacing cfn-tools and ec2-tools with direct api connections.

* Fri Jun 06 2014 Philip Garrett <philip.garrett@icainformatics.com> - 0.1.8-1
- Added proxypass to expose Puppet on port 80.

* Fri May 30 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.1.7-1
- Upgrading CA, CCX, and AUI to newer versions

* Fri May 09 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.1.6-1
- Fix for CONFIGMGMT-134
- Adding feature to track puppet deployment status for an instance
  (CONFIGMGMT-114)

* Mon Apr 28 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.1.5-1
- CONFIGMGMT-86, 94, 98, 107, 112, 120, 121, 123

* Mon Apr 07 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.1.4-1
- Adding feature to create individual security groups for each instance
- Adding EC2 compute types
- Adding error logging
- Adding error progation from the server to the client
- Adding form validation
- Fixed a bug that resulted in a loss of database connectivity

* Tue Mar 25 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.1.3-1
- Updating OS images
- Fix for CONFIGMGMT-85
- Fix for CONFIGMGMT-92

* Wed Mar 12 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.1.2-1
- Adding private ip assignment feature to instances
- Adding new UI theme through bootstrap.css

* Mon Feb 26 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.1.1-1
- Updating server image configuration
- Adding stack definition ingestion script
- Adding database tables for stack definitions

* Fri Jan 31 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.8-1
- Adding caching through memcached

* Fri Jan 24 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.7-1
- Adding functionality to remove systems from spacewalk upon stack destruction

* Tue Jan 21 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.6-1
- Updated configuration for new image ids

* Mon Jan 06 2014 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.5-1
- Added instance detail view

* Wed Dec 18 2013 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.4-1
- Fixed display of multiple views when trying to navigate during an ajax call
- Adding upates to image values in stackit.conf
- Added Admin UI version 1.6.0

* Tue Nov 22 2013 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.3-2
- Added instance view summary for a stack
- Added controls to toggle an instance on/off
- Enabling ec2 tools by adding profile to /etc/sysconfig/httpd

* Tue Nov 22 2013 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.3-1
- Added instance view summary for a stack
- Added controls to toggle an instance on/off

* Tue Nov 05 2013 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.2-1
- Added view to modify options for instances

* Tue Oct 22 2013 Frank Pickle <rpmbuild@icainformatics.com> - 0.0.1-1
- Initial build
