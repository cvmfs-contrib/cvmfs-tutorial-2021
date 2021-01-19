# Stratum 1 and proxies

In the previous section we have set up a Stratum 0 server and a client that directly connects to the Stratum 0.
Although this worked fine, this setup is neither scalable, nor very reliable, nor secure: it is a single point of failure,
too open in terms of connectivity, and it will have to serve all possible clients on its own.

Therefore, this section will show how all these points can be addressed by adding one or more Stratum 1 servers and caching proxy servers. A Stratum 1 is a replica server that keeps mirrors of the repositories served by a Stratum 0.
It is basically a web server that periodically synchronizes the contents of the repositories,
and, in contrast to a Stratum 0 server, you can have multiple Stratum 1 servers.
It is recommended to have several ones that are geographically distributed, so that clients always have a nearby Stratum 1 server.
How many you need mostly depends on the distribution and number of clients, but often a few is already sufficient. More scalability can be added with proxies, which we will discuss later in this section.

INSERT IMAGE OF CVMFS INFRA HERE

## Set up a Stratum 1 server


### Requirements
A Stratum 1 servers has similar requirements as a Stratum 1 in terms of resources.

In addition to port 80, also port 8000 has to be accessible for a Stratum 1. Furthermore, you need a (free) license key for [Maxmind's Geo API](https://dev.maxmind.com/geoip/geoip2/geolite2/), which you can obtain by [signing up for an account](https://www.maxmind.com/en/geolite2/signup/).

### Installation
For the Stratum 1 you need to install the following packages:
```bash
sudo yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
sudo yum install -y epel-release
sudo yum install -y cvmfs-server
sudo yum install -y mod_wsgi
sudo yum install -y squid
```

### Apache and Squid configuration
We will be running Apache with a Squid frontend (reverse proxy); Apache will be listening internally on port 8080, while Squid needs to listen (externally) on port 80 and 8000, which are the default Stratum 1 ports.

For this we first edit `/etc/httpd/conf/httpd.conf` and change the default:
```
Listen 80
```
to:
```
Listen 127.0.0.1:8080
```

Next, we replace the default contents of `/etc/squid/squid.conf:` with the following:
```
http_port 80 accel
http_port 8000 accel
http_access allow all
cache_peer 127.0.0.1 parent 8080 0 no-query originserver

acl CVMFSAPI urlpath_regex ^/cvmfs/[^/]*/api/
cache deny !CVMFSAPI

cache_mem 128 MB
```

Finally, we start and enable Apache and Squid:
```
sudo systemctl start httpd
sudo systemctl start squid
sudo systemctl enable httpd
sudo systemctl enable squid
```


### DNS cache
As a Stratum 1 server does a lot of DNS lookups, it is recommended to have a local DNS caching server on that same machine.
We will not discuss this topic any further here, but you can use `dnsmasq`, `bind`, or `systemd-resolved`.
See for instance (this tutorial)[https://geekflare.com/linux-server-local-dns-caching/] for setting up `systemd-resolved`.

### Create the Stratum 1 replica
With all the required components in place, we can now really set up our Stratum 1 replica server. We first add our Geo API key to the CernVM-FS server settings:
```
echo 'CVMFS_GEO_LICENSE_KEY=YOUR_KEY' | sudo tee -a /etc/cvmfs/server.local
sudo chmod 600 /etc/cvmfs/server.local
```

We also need to have the public keys of all repositories we want to mirror to be available on our Stratum 1. This can be done by copying all the corresponding `.pub` files from `/etc/cvmfs/keys` on your Stratum 0 server to
`/etc/cvmfs/keys/organization.tld/` (note the extra level!) on your Stratum 1 server.

Now we make the replica by giving the URL to the repository on the Stratum 0 server (which is always like `http://host:port/cvmfs/repository`) and the path to the corresponding public key:
```
sudo cvmfs_server add-replica -o $USER http://YOUR_STRATUM0/cvmfs/repo.organization.tld /etc/cvmfs/keys/organization.tld/repo.organization.tld
```

#### Remove the replica
If you ever want to remove the replica again, you can use the `rmfs` subcommand in the same way as on a Stratum 0:
```
sudo cvmfs_server rmfs repo.organization.tld
```

### Manually synchronize the Stratum 1
The Stratum 1 has been registered, so now we should try to do a first synchronization.
You can do this by running the following command:
```
cvmfs_server snapshot repo.organization.tld
```
As there is not much in the repository yet, this should complete within a few seconds.

### Make cronjobs

Whenever you make changes to the repository, the changes have to be synchronized to all Stratum 1 servers. Furthermore, the Geo database has to be updated regularly.

Both tasks can be automated by setting up cronjobs that periodically run `cvmfs_server update-geodb` and `cvmfs_server snapshot -a`, where `-a` does the synchronization for all active repositories. This option will give an error if no log rotation has been configured for CernVM-FS, so we first have to create a file `/etc/logrotate.d/cvmfs` with the following contents:

```
/var/log/cvmfs/*.log {
    weekly
    missingok
    notifempty
}
```

Now we can make a cronjob `/etc/cron.d/cvmfs_stratum1_snapshot` for the snapshots:

```
*/5 * * * * root output=$(/usr/bin/cvmfs_server snapshot -a -i 2>&1) || echo "$output"
```

And another cronjob `/etc/cron.d/cvmfs_geoip_db_update` for updating the Geo database:
```
4 2 2 * * root /usr/bin/cvmfs_server update-geodb
```

## Set up a proxy
If you have a lot of local machines, e.g. a cluster, that need to access your repositories, you also want another cache layer close to these machines. This can be done by adding Squid proxies between your local machine(s) and the layer of Stratum 1 servers.
Usually it is recommended to have at least two of them for reliability and load-balancing reasons.

### Requirements
Just as with the other components, the squid proxy server does not need a lot of resources.
Just a few cores and few gigabytes of memory should be enough. The more disk space you allocate
for this machine, the larger the cache can be, and the better the performance will be. Do note that this machine will only store a part of the (deduplicated and compressed) repository, so it does not need as much space as your Stratum 1.

### Installation
The proxy server only requires Squid to be installed:
```
sudo yum install -y squid
```

### Configuration
The configuration of a standalone Squid is slightly different from the one that we used for our Stratum 1. You can use the following template to set up your own configuration:

```
# List of local IP addresses (separate IPs and/or CIDR notation) allowed to access your local proxy
acl local_nodes src YOUR_CLIENT_IPS

# Destination domains that are allowed
#acl stratum_ones dstdomain .YOURDOMAIN.ORG
#acl stratum_ones dstdom_regex YOUR_REGEX

# Squid port (default: 3128)
# http_port 3128

# Deny access to anything which is not part of our stratum_ones ACL.
http_access deny !stratum_ones

# Only allow access from our local machines
http_access allow local_nodes
http_access allow localhost

# Finally, deny all other access to this proxy
http_access deny all

minimum_expiry_time 0
maximum_object_size 1024 MB

cache_mem 128 MB
maximum_object_size_in_memory 128 KB
# 50 GB disk cache
cache_dir ufs /var/spool/squid 50000 16 256
```

You should use the `local_nodes` ACL here to specify which clients are allowed to use this proxy; you can use [CIDR notation](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing#CIDR_notation).

Furthermore, you probably also want to have an ACL that specifies that your Squid should only cache the Stratum 1 servers. The template uses a `stratum_ones` ACL for this, and you can make use of either `dstdomain` (in case you have a single domain for all your Stratum 1 servers) or `dstdom_regex` for more complex situations.

More information about Squid ACLs can be found in the (Squid documentation)[http://www.squid-cache.org/Doc/config/acl/].

Finally, there are some settings regarding the size of your cache. Make sure that you have enough disk space for the value that you provide.

### Starting Squid
Before you actually start Squid, you can verify the correctness of your configuration with `sudo squid -k parse`. When you are sure things are okay, start and enable Squid:
```
sudo systemctl start squid
sudo systemctl enable squid
```

## Client configuration
Now that we have a Stratum 0, one ore more Stratum 1 servers, and one or more local Squid proxies, all the infrastructure for a production-ready CernVM-FS setup is in place. This means that we can now configure our client properly, and start using the repository.

In the previous section we connected our client directly to the Stratum 0. We are going to reuse that configuration, and only need to change two things.

### Connect to the Stratum 1
We used the URL of the Stratum 0 in the file `/etc/cvmfs/config.d/repo.organization.tld.conf`. We should now change this URL, and point to the Stratum 1 instead:
```
CVMFS_SERVER_URL="http://your-stratum1/cvmfs/@fqrn@"
```

When you have more Stratum 1 servers inside the organization, you can make it a semicolon-separated list of servers. The Geo API will make sure that your client always connects to the geographically closest Stratum 1 server.

### Use the Squid proxy
In order to use the local cache layer of our proxy, we have to instruct the client to send all requests through the proxy. This needs one small change in `/etc/cvmfs/default.local`, where you will have to set:
```
CVMFS_HTTP_PROXY="http://your-proxy:3128"
```

More proxies can be added to that list by separating them with a pipe symbol. See for more (complex) examples [this documentation page](https://cvmfs.readthedocs.io/en/stable/cpt-configure.html#proxy-list-examples).


## Homework
- Set up a Stratum 1 server. Make sure that it includes:
 - a proper Geo API license key;
 - cronjobs for automatically synchronizing the database and updating the Geo database;
 - properly configured Apache and Squid services;
- Set up a separate Squid proxy. Though it is recommended to at least have two in production, one is enough for now.
- #TODO: reuse or set up a new client?? Add firewall rules to the Stratum 0?
  Reconfigure the client that you set up in the previous section and make sure that it uses your Stratum 1 and Squid proxy.
