#!/usr/local/bin/perl
# config_save.cgi
# Save inputs from config.cgi

require './web-lib.pl';
require './config-lib.pl';
&init_config();
&switch_to_remote_user();
&create_user_config_dirs();

&ReadParse();
$m = $in{'module'};
&read_acl(\%acl);
&error_setup($text{'config_err'});
$acl{$base_remote_user,$m} || &error($text{'config_eaccess'});

mkdir("$user_config_directory/$m", 0700);
&lock_file("$user_config_directory/$m/config");
&read_file("$user_config_directory/$m/config", \%config);
&read_file("$config_directory/$m/canconfig", \%canconfig);

if (-r "$m/uconfig_info.pl") {
	# Module has a custom config editor
	&foreign_require($m, "uconfig_info.pl");
	eval "\%${m}::in = \%in";
	&foreign_call($m, "config_save", \%config, \%canconfig);
	}
else {
	# Use config.info to parse config inputs
	&parse_config(\%config, "$m/uconfig.info", undef,
		      %canconfig ? \%canconfig : undef);
	}
&write_file("$user_config_directory/$m/config", \%config);
&unlock_file("$user_config_directory/$m/config");
&redirect("/$m/");
