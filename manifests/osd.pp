#
#   Copyright (C) 2014 Cloudwatt <libre.licensing@cloudwatt.com>
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
# Author: David Gurtner <aldavud@crimson.ch>
# Author: Can Zhang <zhangcan@letv.com>
#
### == Parameters
# [*title*] The OSD data path.
#   Mandatory. A path in which the OSD data is to be stored.
#
# [*ensure*] Installs ( present ) or remove ( absent ) an OSD
#   Optional. Defaults to present.
#   If set to absent, it will stop the OSD service and remove
#   the associated data directory.
#
# [*journal*] The OSD journal path.
#   Optional. Defaults to co-locating the journal with the data
#   defined by *title*.
#
# [*cluster*] The ceph cluster name
#   Optional. Default to ceph.
#
# [*hd_path*] The path of the hard disk to use
#   Optional. If osd is running on a new hard disk, you should
#   specify this variable, e.g. /dev/sda, and puppet will automatically
#   prepare the disk for Ceph.
#   You must provide one of hd_path/partition_path
#
# [*partition_path*] The path of the partition to use
#   Optional. If specified, puppet will directly mount the partition
#   to the target directory. 
#   e.g. mount /dev/sdb1 /var/lib/ceph/osd/ceph-osd1
#   You must provide one of hd_path/partition_path
#
# [*format*] Format of the new hard disk
#   Default to xfs. Effective only if hd_path is set.
#
define ceph::osd (
        $ensure = present,
        $journal = undef,
        $cluster = undef,
        $hd_path = undef,
        $partition_path = undef,
        $format = 'xfs',
        $raid0 = false,
)
{
    if !($hd_path or $partition_path) {
        fail("You must provide one of: hd_path, partition_path")
    }

    if $cluster {
        $cluster_option = "--cluster ${cluster}"
        $cluster_name = $cluster
    } else {
        $cluster_name = 'ceph'
    }

    if $ensure == present {

        # prepare disk
        if $hd_path {
            # part the disk into one partition use all free space
            exec {"make_gpt_${name}":
                command => "/sbin/parted --script ${hd_path} mklabel gpt",
                # e.g. if hd_path = /dev/sdb, check if /dev/sdb1 exists
                # hopefully this will reveal if the disk is parted
                unless => "/sbin/parted ${hd_path} print|grep -q gpt",
            }
            exec {"partition_disk_${name}":
                command => "/sbin/parted --script --align optimal ${hd_path} mkpart osd 0% 100%",
                require => Exec["make_gpt_${name}"],
                unless =>  "/sbin/parted ${hd_path} print|grep -q osd",
            }

            if $raid0 {
                exec {"format_partition_${name}":
                    command => "/sbin/mkfs.${format} -i size=2048 -f ${hd_path}1 -d su=64k -d sw=2",
                    require => Exec["partition_disk_${name}"],
                    onlyif => "/usr/sbin/xfs_check ${hd_path}1 2>&1 >/dev/null | grep -q \"not a valid XFS filesystem\"",
                    before => [ Exec["mount_partition_${name}"],
                                Exec["get_osd_number_${name}"],
                              ]
                }
            } else {
                exec {"format_partition_${name}":
                    command => "/sbin/mkfs.${format} -i size=2048 -f ${hd_path}1",
                    require => Exec["partition_disk_${name}"],
                    onlyif => "/usr/sbin/xfs_check ${hd_path}1 2>&1 >/dev/null | grep -q \"not a valid XFS filesystem\"",
                    before => [ Exec["mount_partition_${name}"],
                                Exec["get_osd_number_${name}"],
                              ]
                }
            }
        }

        # mount the partition
        if $partition_path == undef {
            $_partition_path = "${hd_path}1"
        } else {
            $_partition_path = $partition_path
        }
        exec {"mount_partition_${name}":
            command => "/bin/mount -o noatime,nodiratime,inode64 -t ${format} ${_partition_path} /var/lib/ceph/osd/${cluster_name}-`cat /var/lib/ceph/osd/osd_number_${name}`",
            require => Exec["mkdir_${name}"],
            before =>  Exec["mkfs_${name}"],
            unless => "/bin/mount |grep -q ${_partition_path}",
        }

        Ceph_Config<||> -> Exec["get_osd_number_${name}"]
        Ceph::Mon<||> -> Exec["get_osd_number_${name}"]
        Ceph::Firstmon<||> -> Exec["get_osd_number_${name}"]
        Ceph::Key<||> -> Exec["get_osd_number_${name}"]

        exec {"get_osd_number_${name}":
            command => "/usr/bin/ceph osd create > /var/lib/ceph/osd/osd_number_${name}",
            creates => "/var/lib/ceph/osd/osd_number_${name}",
        }
        exec {"mkdir_${name}":
            command => "/bin/mkdir /var/lib/ceph/osd/${cluster_name}-`cat /var/lib/ceph/osd/osd_number_${name}`",
            require => Exec["get_osd_number_${name}"],
            unless => "/bin/ls /var/lib/ceph/osd/${cluster_name}-`cat /var/lib/ceph/osd/osd_number_${name}` > /dev/null",
        }
        exec {"mkfs_${name}":
            command => "/usr/bin/ceph-osd ${cluster_option} -i `cat /var/lib/ceph/osd/osd_number_${name}` --mkfs --mkkey",
            require => Exec["mkdir_${name}"],
            unless => "/bin/cat /var/lib/ceph/osd/${cluster_name}-`cat /var/lib/ceph/osd/osd_number_${name}`/keyring >> /dev/null",
        }
        exec {"create_sysvinit_${name}":
            command => "/bin/touch /var/lib/ceph/osd/${cluster_name}-`cat /var/lib/ceph/osd/osd_number_${name}`/sysvinit",
            require => Exec["mkfs_${name}"],
            unless => "/bin/cat /var/lib/ceph/osd/${cluster_name}-`cat /var/lib/ceph/osd/osd_number_${name}`/sysvinit >> /dev/null",
        }
        exec {"add_osd_permission_${name}":
            command => "/usr/bin/ceph auth add osd.`cat /var/lib/ceph/osd/osd_number_${name}` osd 'allow *' mon 'allow rwx' -i /var/lib/ceph/osd/${cluster_name}-`cat /var/lib/ceph/osd/osd_number_${name}`/keyring",
            require => Exec["mkfs_${name}"],
            unless => "/usr/bin/ceph auth list|grep -q osd.`cat /var/lib/ceph/osd/osd_number_${name}`"
        }
        exec {"calc_weight_${name}":
            command => "/bin/df -P -k /var/lib/ceph/osd/ceph-`cat /var/lib/ceph/osd/osd_number_${name}`/. | tail -1 | awk '{ print sprintf(\"%.2f\",\$2/1073741824) }' > /var/lib/ceph/osd/osd_weight_${name}",
            require => Exec["mount_partition_${name}"],
            before => Exec["add_osd_${name}"],
        }
        exec {"add_osd_${name}":
            command => "/usr/bin/ceph osd crush add osd.`cat /var/lib/ceph/osd/osd_number_${name}` `cat /var/lib/ceph/osd/osd_weight_${name}` root=default host=${::hostname}",
            require => Exec["add_osd_permission_${name}"],
            unless => "/usr/bin/ceph osd crush dump|grep -q osd.`cat /var/lib/ceph/osd/osd_number_${name}`",
        }
        exec {"start_osd_service_${name}":
            command => "/etc/init.d/ceph start osd.`cat /var/lib/ceph/osd/osd_number_${name}`",
            require => [ Exec["add_osd_${name}"],
                         Exec["create_sysvinit_${name}"],
                       ]
        }

    } else { # $ensure != present
        exec {"stop_osd_service_${name}":
            command => "/etc/init.d/ceph stop osd.`cat /var/lib/ceph/osd/osd_number_${name}`",
        }
    }
}
