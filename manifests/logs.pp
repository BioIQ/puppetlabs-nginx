# Class: nginx::logs
#
# This module manages NGINX logs
#
# Parameters:
#
# There are no default parameters for this class.
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# This class file is not called directly
class nginx::logs(
  $rotate_schedule = $nginx::params::nx_log_rotate_schedule,
  $rotate_keep     = $nginx::params::nx_log_rotate_keep,
  $archive_dir     = $nginx::params::nx_log_archive_dir,
) inherits nginx::params {

  File { owner  => "nginx", group  => "root" }

  if $archive_dir != '' {
    file { $archive_dir : ensure => directory, mode => 0644 }
  }

  logrotate::rule { "nginx" :
    path          => "${nx_logdir}/*.log",
    rotate        => $rotate_keep,
    rotate_every  => $rotate_schedule,
    compress      => true,
    olddir        => $archive_dir ? {
      ''      => undef,
      default => $archive_dir
    },
    ifempty       => false,
    missingok     => true,
    sharedscripts => true,
    postrotate    => "/etc/init.d/nginx reopen_logs 2>/dev/null || /bin/kill -USR1 `cat /var/run/nginx.pid 2>/dev/null` 2>/dev/null || logger 'logrotate for nginx failed'",
    dateext       => true
  }
}
