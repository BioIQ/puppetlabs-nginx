# define: nginx::resource::location
#
# This definition creates a new location entry within a virtual host
#
# Parameters:
#   [*ensure*]               - Enables or disables the specified location (present|absent)
#   [*vhost*]                - Defines the default vHost for this location entry to include with
#   [*location*]             - Specifies the URI associated with this location entry
#   [*www_root*]             - Specifies the location on disk for files to be read from. Cannot be set in conjunction with $proxy
#   [*index_files*]          - Default index files for NGINX to read when traversing a directory
#   [*proxy*]                - Proxy server(s) for a location to connect to. Accepts a single value, can be used in conjunction
#                              with nginx::resource::upstream
#   [*proxy_read_timeout*]   - Override the default the proxy read timeout value of 90 seconds
#   [*ssl*]                  - Indicates whether to setup SSL bindings for this location.
#   [*ssl_only*]	     - Required if the SSL and normal vHost have the same port.
#   [*location_alias*]       - Path to be used as basis for serving requests for this location
#   [*stub_status*]          - If true it will point configure module stub_status to provide nginx stats on location
#   [*location_cfg_prepend*] - It expects a hash with custom directives to put before anything else inside location
#   [*location_cfg_append*]  - It expects a hash with custom directives to put after everything else inside location   
#   [*try_files*]            - An array of file locations to try
#   [*option*]               - Reserved for future use
#
# Actions:
#
# Requires:
#
# Sample Usage:
#  nginx::resource::location { 'test2.local-bob':
#    ensure   => present,
#    www_root => '/var/www/bob',
#    location => '/bob',
#    vhost    => 'test2.local',
#  }
#  
#  Custom config example to limit location on localhost,
#  create a hash with any extra custom config you want.
#  $my_config = {
#    'access_log' => 'off',
#    'allow'      => '127.0.0.1',
#    'deny'       => 'all'
#  }
#  nginx::resource::location { 'test2.local-bob':
#    ensure              => present,
#    www_root            => '/var/www/bob',
#    location            => '/bob',
#    vhost               => 'test2.local',
#    location_cfg_append => $my_config,
#  }

define nginx::resource::location(
  $ensure               = present,
  $vhost                = undef,
  $www_root             = undef,
  $index_files          = ['index.html', 'index.htm', 'index.php'],
  $proxy                = undef,
  $proxy_read_timeout   = $nginx::params::nx_proxy_read_timeout,
  $location_template    = undef,
  $ssl                  = false,
  $ssl_only		          = false,
  $location_alias       = undef,
  $option               = undef,
  $stub_status          = undef,
  $location_cfg_prepend = undef,
  $location_cfg_append  = undef,
  $try_files            = undef,
  $non_ssl_file_order   = '500',
  $ssl_file_order       = '800',
  $auth_basic           = undef,
  $auth_file            = undef,
  $auth_location        = $nginx::params::nx_auth_dir,
  $location
) {
  File {
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Class['nginx::service'],
  }

  ## Shared Variables
  $ensure_real = $ensure ? {
    'absent' => absent,
    default  => file,
  }

  # Auth 
  if $auth_basic {
    if ($auth_file == undef) {
      fail('nginx: must specify auth_file if using auth_basic')
    }

    $auth_file_path = "${auth_location}/${vhost}-${name}-auth"
    file { $auth_file_path:
      ensure => $ensure_real,
      content => template($auth_file)
    }

    $auth_content = template('nginx/vhost/vhost_auth.erb')
  }

  # Use proxy template if $proxy is defined, otherwise use directory template.
  if ($location_template) {
    $content_real = template($location_template)
  } elsif ($proxy != undef) {
    $content_real = template('nginx/vhost/vhost_location_proxy.erb')
  } elsif ($location_alias != undef) {
    $content_real = template('nginx/vhost/vhost_location_alias.erb')
  } elsif ($stub_status != undef) {
    $content_real = template('nginx/vhost/vhost_location_stub_status.erb')
  } else {
    $content_real = template('nginx/vhost/vhost_location_directory.erb')
  }

  $final_content = $auth_basic ? {
    undef   => $content_real,
    default => "${content_real}${auth_content}"
  }

  ## Check for various error condtiions
  if ($vhost == undef) {
    fail('Cannot create a location reference without attaching to a virtual host')
  }
  if (($location_template == undef) and ($www_root == undef) and ($proxy == undef) and ($location_alias == undef) and ($stub_status == undef) ) {
    fail('Cannot create a location reference without a www_root, proxy, location_alias or stub_status defined')
  }
  if (($www_root != undef) and ($proxy != undef)) {
    fail('Cannot define both directory and proxy in a virtual host')
  }

  ## Create stubs for vHost File Fragment Pattern
  if ($ssl_only != true) {
    file {"${nginx::config::nx_temp_dir}/nginx.d/${vhost}-${non_ssl_file_order}-${name}":
      ensure  => $ensure_real,
      content => $final_content,
    }
  }

  ## Only create SSL Specific locations if $ssl is true.
  if ($ssl == true) {
    file {"${nginx::config::nx_temp_dir}/nginx.d/${vhost}-${ssl_file_order}-${name}-ssl":
      ensure  => $ensure_real,
      content => $final_content,
    }
  }
}
