ceph
====

#### Table of Contents

1. [Overview - What is the ceph module?](#overview)
2. [Module Description - What does the module do?](#module-description)
3. [使用说明 - 如何使用本模块部署ceph](#使用)
4. [Release Notes - Notes on the most recent updates to the module](#release-notes)

Overview
========

The ceph module is intended to leverage all [Ceph](http://ceph.com/) has to offer and allow for a wide range of use case. Although hosted on the OpenStack infrastructure, it does not require to sign a CLA nor is it restricted to OpenStack users. It benefits from a structured development process that helps federate the development effort. Each feature is tested with integration tests involving virtual machines to show that it performs as expected when used with a realistic scenario.

Module Description
==================

The ceph module deploys a [Ceph](http://ceph.com/) cluster ( MON, OSD ), the [Cephfs](http://ceph.com/docs/next/cephfs/) file system and the [RadosGW](http://ceph.com/docs/next/radosgw/) object store. It provides integration with various environments ( OpenStack ... ) and components to be used by third party puppet modules that depend on a Ceph cluster.

使用
====

前置条件
-------
* ntp服务已配置好
* 防火墙允许Ceph流量，其中
	* 6789端口：用于monitor(mon)
	* 6800~7100端口：用于osd
* puppet启用`parser = future`选项(在master节点`puppet.conf`的`[main]`section配置)

部署
----
整体的部署顺序为：第一个monitor -> 其它monitor -> osd

由于puppet不能控制节点之间的部署顺序，所以此处需要人工控制顺序

配置site.pp
-----------
样例文件请参见[`examples/site.pp`](./examples/site.pp)

1. 使用`uuidgen`命令生成一个uuid，配置到

    	$ceph_uuid = '8f8f475a-3686-4150-a34e-74fed8060574'
    
2. 使用`ceph-authtool  --gen-print-key`命令生成两个ceph可用的key
			
		$admin_key = 'AQA44VlUwBC6MxAAfvJilmb88ygeQFzP1zbvgw=='
		$mon_key = 'AQBN4VlUSOmeDBAAy/AJkS+xGdXWq0VOErkdEA=='
3. 配置public network和cluster network的地址
		
		$public_network = '10.58.0.0/16'
		$cluster_network = '192.168.56.0/24'
4. 配置monitor节点的IP地址，至少3台
		
		$mon_hosts = '10.58.106.194,10.58.106.244,10.58.106.31'
5. 确定哪台机器会首个安装monitor，e.g.`ceph0`。对这台机器配置以下内容：
	* `ceph::repo`: ceph源的地址
	* `ceph`: 安装ceph包，并且配置`ceph.conf`文件
	* `ceph::key`: 添加`ceph.client.admin.kerying`，配置权限
	* `ceph::firstmon`: 安装第一个monitor。`public_addr`应写为形式`$::ipaddress_X`，其中`X`为该机器在public network上的网卡名称
		
			$mon_initial_member = 'ceph0'
		
			node 'ceph0' {
    			class {'ceph::repo':
        			ensure => present,
    			} ->
    			class {'ceph':
        			fsid => $ceph_uuid,
        			mon_initial_members => $mon_initial_member,
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
6. 安装其它monitor，使用`ceph::mon`而不是`ceph::firstmon`。另外注意到node的匹配可以[使用正则表达式](https://docs.puppetlabs.com/puppet/latest/reference/lang_node_definitions.html#regular-expression-names)

		node /ceph[23]/ {
    		class {'ceph::repo':
        		ensure => present,
    		} ->
    		class {'ceph':
        		fsid => $ceph_uuid,
        		mon_initial_members => $initial_member,
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
    		}
    	}
7. 添加osd。在需要添加osd的机器上执行
    
        class {'ceph::osds':
                hd_paths => ['/dev/sdb', '/dev/sdc'],
        }
其中`hd_paths`是新硬盘(未分区)的路径，另外也可以使用例如`partition_paths => ['/dev/sdb1', '/dev/sdb2']`的格式使用已分区的硬盘。


Release Notes
-------------
基于stackforge/puppet-ceph，修改了mon/osd相关文件。
