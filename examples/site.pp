$admin_key = 'AQA44VlUwBC6MxAAfvJilmb88ygeQFzP1zbvgw=='
$mon_key = 'AQBN4VlUSOmeDBAAy/AJkS+xGdXWq0VOErkdEA=='
$ceph_uuid = '8f8f475a-3686-4150-a34e-74fed8060574'
$mon_initial_member = 'ceph0'
$mon_hosts = '10.58.106.194,10.58.106.244,10.58.106.31'
$public_network = '10.58.0.0/16'
$cluster_network = '192.168.56.0/24'


node 'ceph0' {
    class {'ceph::repo':
        ensure => present,
    } ->
    class {'ceph':
        fsid => $ceph_uuid,
        mon_initial_members => $mon_initial_memeber,
        mon_host => $mon_hosts,
        public_network => $public_network,
        cluster_network => $cluster_network,
    } ->
    ceph::key{'client.admin':
        secret => $admin_key,
        cap_mon => 'allow *',
        cap_osd => 'allow *',
        cap_mds => 'allow',
    } ->
    ceph::firstmon{'ceph0':
        fsid => $ceph_uuid,
        public_addr => $::ipaddress_eth0,
        mon_key => $mon_key,
    }
}

node /ceph[23]/ {
    class {'ceph::repo':
        ensure => present,
    } ->
    class {'ceph':
        fsid => $ceph_uuid,
        mon_initial_members => $initial_memeber,
        mon_host => $mon_hosts,
        public_network => $public_network,
        cluster_network => $cluster_network,
    } ->
    ceph::key{'client.admin':
        secret => $admin_key,
        cap_mon => 'allow *',
        cap_osd => 'allow *',
        cap_mds => 'allow',
    } ->
    ceph::mon{$::hostname:
        public_addr => $::ipaddress_eth1,
        mon_key => $mon_key,
    } ->
    class {'ceph::osds':
        hd_paths => ['/dev/sdb', '/dev/sdc'],
    }
}
