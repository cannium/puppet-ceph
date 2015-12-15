#
#   Copyright (C) 2014 Nine Internet Solutions AG
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
#
# Profile for a Ceph osd
#
class ceph::profile::osd {
  require ceph::profile::base

  # this supports providing the key manually
  if $ceph::profile::params::bootstrap_osd_key {
    if ! defined(Ceph::Key['client.bootstrap-osd']) {
      ceph::key { 'client.bootstrap-osd':
        keyring_path => '/var/lib/ceph/bootstrap-osd/ceph.keyring',
        secret       => $ceph::profile::params::bootstrap_osd_key,
      }
    }
  }

  class { 'ceph::osds':
    args => $ceph::profile::params::osds,
  }
}
