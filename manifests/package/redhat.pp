# Class: nginx::package::redhat
#
# This module manages NGINX package installation on RedHat based systems
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
class nginx::package::redhat {
  $redhat_packages = ['nginx', 'GeoIP', 'gd', 'libXpm', 'libxslt']

  # Why is this even necessary? We're already in the redhat package
  $os_type = downcase($::osfamily) ? {
    default  => downcase($::operatingsystem),
    'redhat' => "rhel",
  }

  if $::lsbmajdistrelease == undef {
    $os_rel = regsubst($::operatingsystemrelease, '\..*$', '')
  } else {
    $os_rel = $::lsbmajdistrelease
  }

  yumrepo { "nginx-release":
    baseurl  => "http://nginx.org/packages/${os_type}/${os_rel}/\$basearch/",
    descr    => 'nginx repo',
    enabled  => '1',
    gpgcheck => '0',
  }

  package { $redhat_packages:
    ensure  => present,
    require => Yumrepo['nginx-release'],
  }
}
