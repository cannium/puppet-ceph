#
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
# Author: David Gurtner <aldavud@crimson.ch>
# Author: Can Zhang <zhangcan@letv.com>
#
# Class wrapper to imporve user experience
#
# NOTE: You need to enable `parser=future` in puppet.conf if you use 3.x
# since `each` function is introduced since 4.0
#
# [*hd_paths*] The paths of the hard disk to use
#   Optional. Should be an array. e.g. ['/dev/sdb', '/dev/sdc']
#   If osd is running on a new hard disk, you should
#   specify this variable, e.g. /dev/sdb, and puppet will automatically
#   prepare the disk for Ceph.
#   You must provide one of hd_paths/partition_paths
#
# [*partition_paths*] The path of the partition to use
#   Optional. Should be an array. e.g. ['/dev/sda1', '/dev/sda2']
#   If specified, puppet will directly mount the partition
#   to the target directory. 
#   e.g. mount /dev/sda1 /var/lib/ceph/osd/ceph-osd1
#   You must provide one of hd_paths/partition_paths


class ceph::osds(
        $hd_paths = undef,
        $partition_paths = undef,
        $osd_max_backfills = 2,
        $osd_backfill_scan_min = 16,
        $osd_backfill_scan_max = 256,
        $filestore_op_threads = 4,
        $filestore_xattr_use_omap = 'false',
        $filestore_journal_writeahead = 'true',
        $osd_recovery_max_active = 1,
        $osd_recovery_max_chunk = '32M',
        $osd_recovery_threads = 1,
        $journal_max_write_bytes = '32M',
        $journal_queue_max_bytes = '32M',
        $raid0 = false,
        $osd_heartbeat_interval = 180,
        $osd_heartbeat_grace = 500
)
{
    ceph_config {
        'osd/osd_max_backfills':    value => $osd_max_backfills;
        'osd/osd_backfill_scan_min':    value => $osd_backfill_scan_min;
        'osd/osd_backfill_scan_max':    value => $osd_backfill_scan_max;
        'osd/filestore_op_threads': value => $filestore_op_threads;
        'osd/filestore_xattr_use_omap': value => $filestore_xattr_use_omap;
        'osd/filestore_journal_writeahead': value => $filestore_journal_writeahead;
        'osd/osd_recovery_max_active': value => $osd_recovery_max_active;
        'osd/osd_recovery_max_chunk':   value => $osd_recovery_max_chunk;
        'osd/osd_recovery_threads': value => $osd_recovery_threads;
        'osd/journal_max_write_bytes':  value => $journal_max_write_bytes;
        'osd/journal_queue_max_bytes':  value => $journal_queue_max_bytes;
        'osd/osd_heartbeat_interval':  value => $osd_heartbeat_interval;
        'osd/osd_heartbeat_grace':     value => $osd_heartbeat_grace;
    }

    if $hd_paths {
        each($hd_paths) |$index, $value| {
            ceph::osd{"${::hostname}-${index}":
                hd_path => $value,
                raid0 => $raid0,
            }
        }
    }
    if $partition_paths {
        each($partition_paths) |$index, $value| {
            ceph::osd{"${::hostname}-${index}":
                partition_path => $value,
                raid0 => $raid0,
            }
        }
    }
}
