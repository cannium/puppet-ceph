#
#   Copyright (C) 2013 Cloudwatt <libre.licensing@cloudwatt.com>
#   Copyright (C) 2013, 2014 iWeb Technologies Inc.
#   Copyright (C) 2014 Nine Internet Solutions AG
#   Copyright (C) 2014 Letv Cloud Computing
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Author: Loic Dachary <loic@dachary.org>
# Author: David Moreau Simard <dmsimard@iweb.com>
# Author: David Gurtner <aldavud@crimson.ch>
# Author: Can Zhang <zhangcan@letv.com>
#
# Installs and configures additional Ceph monitors(not the first one)
### == Parameters
# [*title*] The MON id.
#   Mandatory. An alphanumeric string uniquely identifying the MON.
#
# [*ensure*] Installs ( present ) or stops( absent ) a MON
#   Optional. Defaults to present.
#   If set to absent, it will stop the MON service.
#
# [*public_addr*] The bind IP address.
#   Optional. The IPv(4|6) address on which MON binds itself.
#
# [*cluster*] The ceph cluster name
#   Optional. Same default as ceph.
#
# [*authentication_type*] Activate or deactivate authentication
#   Optional. Default to cephx.
#   Authentication is activated if the value is 'cephx' and deactivated
#   if the value is 'none'. If the value is 'cephx', key or keyring must
#   be provided.
#   Option "none" is not tested.
#
# [*key*] Authentication key for [mon.]
#   Optional. $key and $keyring are mutually exclusive.
#
# [*keyring*] Path of the [mon.] keyring file
#   Optional. $key and $keyring are mutually exclusive.
#
define ceph::mon (
    $ensure = present,
    $public_addr = undef,
    $cluster = undef,
    $authentication_type = 'cephx',
    $mon_key = undef,
    $admin_keyring  = '/etc/ceph/ceph.client.admin.keyring',
)
{
    # a puppet name translates into a ceph id, the meaning is different
    $id = $name

    $mon_service = "ceph-mon-${id}"

    if $cluster {
        $cluster_name = $cluster
        $cluster_option = "--cluster ${cluster_name}"
    } else {
        $cluster_name = 'ceph'
    }

    if $::operatingsystem == 'Ubuntu' {
    $init = 'upstart'
        Service {
            name     => $mon_service,
            # workaround for bug https://projects.puppetlabs.com/issues/23187
            provider => 'init',
            start    => "start ceph-mon id=${id}",
            stop     => "stop ceph-mon id=${id}",
            status   => "status ceph-mon id=${id}",
        }
    } elsif ($::operatingsystem == 'Debian') or ($::osfamily == 'RedHat') {
        $init = 'sysvinit'
        Service {
            name     => $mon_service,
            start    => "service ceph start mon.${id}",
            stop     => "service ceph stop mon.${id}",
            status   => "service ceph status mon.${id}",
        }
    } else {
        fail("operatingsystem = ${::operatingsystem} is not supported")
    }
    if $ensure == present {
        $ceph_mkfs = "ceph-mon-mkfs-${id}"
        if $authentication_type == 'cephx' {
            $temp_keyring_path = '/tmp/tmp.keyring'
        } else {
            $temp_keyring_path = '/dev/null'
        }

        File[$temp_keyring_path] -> Exec[$ceph_mkfs]
        file {$temp_keyring_path:
            mode        => '0600',
            content     => "[mon.]\n\tkey = ${mon_key}\n\tcaps mon = \"allow *\"\n",
        }

        Ceph_Config<||> ->
        exec {'import_monitor_map':
            command => "/usr/bin/ceph mon getmap -o /tmp/monmap",
            before => Exec[$ceph_mkfs],
        }

        if $public_addr {
            $public_addr_option = "--public-addr ${public_addr}"
        }

        file {"/var/lib/ceph/mon/${cluster_name}-${id}/done":
            ensure => present,
            mode => '0644',
            require => Exec[$ceph_mkfs],
            before => Service[$mon_service],
        }
        file {"/var/lib/ceph/mon/${cluster_name}-${id}/${init}":
            ensure => present,
            mode => '0644',
            require => Exec[$ceph_mkfs],
            before => Service[$mon_service],
        }

        Ceph_Config<||> ->
        exec {$ceph_mkfs:
            command => "/usr/bin/ceph-mon ${cluster_option} ${public_addr_option} --mkfs --id ${id} --keyring ${temp_keyring_path} --monmap /tmp/monmap",
            logoutput => true,
            creates => "/var/lib/ceph/mon/${cluster_name}-${id}"
        }
        ->
        service {$mon_service:
            ensure => running,
        }
    } else { # ensure != present
        service { $mon_service:
            ensure => stopped
        }
    }
}
