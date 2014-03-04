# Class: odaijbossslavebb
#
# This module manages odaijbossslavebb
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class odaijbossslavebb (
  $package_url             = "http://",
  $bind_address            = $::ipaddress,
  $deploy_dir              = "/opt/jboss",
  $mode                    = "domain",
  $bind_address_management = $::ipaddress,
  $bind_address_unsecure   = $::ipaddress,
  $admin_user              = $::hostname,
  $admin_user_password     = hiera('jbossadminslavepwdbb', ""),
  $master_ip               = '',) {
  $teiidjboss = hiera('teiidjboss', undef)

  package { 'unzip': ensure => present, }

  package { 'bind-utils': ensure => present, }

  class { 'opendai_java':
    distribution => 'jdk',
    version      => '6u25',
    repos        => $package_url,
  }

  notify { "${master_ip}": #    require => Odaijbossslave::SetMaster['setMasterIP']
   }

  class { 'jbossas':
    package_url             => "http://$package_url/",
    bind_address            => $bind_address,
    deploy_dir              => $deploy_dir,
    mode                    => $mode,
    role                    => 'slave',
    bind_address_management => $bind_address_management,
    bind_address_unsecure   => $bind_address_unsecure,
    domain_master_address   => $master_ip,
    admin_user              => $admin_user,
    admin_user_password     => $admin_user_password,
    require                 => [Class['opendai_java'], Package['unzip'], Package['bind-utils']],
    before                  => Anchor['odaijbossslavebb:master_installed'],
  }

  anchor { 'odaijbossslavebb:master_installed': }

  @@jbossas::add_user { $admin_user:
    password => $admin_user_password,
    tag      => $teiidjboss["user_tag"]
  }

  #

  @@jbossas::add_server { 'geo2':
    jbhost_name  => $::hostname,
    server_group => "geo-server-group",
    autostart    => "true",
    tag          => $teiidjboss["server_slave_tag"]
  }

  @@jbossas::add_server { 'teiid2':
    jbhost_name  => $::hostname,
    server_group => "teiid-server-group",
    autostart    => "true",
    tag          => $teiidjboss["server_slave_tag"]
  }

  # mount NFS
  $geodata = '/var/geo_data'

  file { $geodata:
    ensure => directory,
    owner  => "$jbossas::params::jboss_user",
    group  => "$jbossas::params::jboss_group",
    mode   => 0775,
  #    require => [Group["$jbossas::jboss_group"], User["$jbossas::jboss_user"]]
  }
  include nfs::client
  Nfs::Client::Mount <<| tag == 'nfs_geoserver' |>> {
    ensure  => 'mounted',
    mount   => $geodata,
    options => 'rw,sync,hard,intr',
    before  => Anchor['odaijbossslave:nfs'],
  }

  anchor { 'odaijbossslave:nfs': }

  # cleanup
  @@jbossas::run_cli_command { 'set_server_one_autostart':
    command => "/host=$::hostname/server-config=server-one:write-attribute(name=auto-start,value=false)",
    #    unless_command => "\"operation\":\"read-resource\", \"include-runtime\":\"true\",
    #    \"address\":[{\"deployment\":\"${geoserver_file}\"}]",
    tag     => $teiidjboss["server_slave_tag"],
    require => [Exec['download_geoserver']]
  }

  @@jbossas::run_cli_command { 'set_server_two_autostart':
    command => "/host=$::hostname/server-config=server-two:write-attribute(name=auto-start,value=false)",
    #    unless_command => "\"operation\":\"read-resource\", \"include-runtime\":\"true\",
    #    \"address\":[{\"deployment\":\"${geoserver_file}\"}]",
    tag     => $teiidjboss["server_slave_tag"],
    require => [Exec['download_geoserver']]
  }

}
