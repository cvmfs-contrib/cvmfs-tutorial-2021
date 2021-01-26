# 1. Introduction to CernVM-FS

## 1.0 Introductory talk by Jakob Blomer

The best possible introduction to CernVM-FS is the talk by Jakob Blomer (CERN, lead developer)
at the 6th EasyBuild User Meeting.

The slides for this talk are available [here](cvmfs-eum21.pdf).

The recording of this presentation is available on YouTube:

<div>
<iframe width="560" height="315" src="https://www.youtube.com/embed/lxZLS3O9wo4" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

## 1.1 What is CernVM-FS?

Let's get started with explaining in detail what CernVM-FS is...

!!! note "CernVM-FS in a nutshell"

    *The CernVM File System (CernVM-FS) provides a scalable and reliable software distribution service,
    which is implemented as a read-only POSIX filesystem in user space (a FUSE module).*

    *Files and directories are hosted on standard web servers and mounted in the universal namespace* ``/cvmfs``.

That's a mouthful, so let's break it down a bit...


#### 1.1.1 Read-only filesystem over HTTP

CernVM-FS is a ***network filesystem***,
which you can mount in Linux or macOS via [FUSE (Filesystem in Userspace)](https://github.com/libfuse/libfuse)
and on Windows in a [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install-win10) virtualized Linux environment.
In some ways it is similar to other network filesystems like [NFS](https://en.wikipedia.org/wiki/Network_File_System)
or [AFS](https://en.wikipedia.org/wiki/Andrew_File_System),
but there are various aspects to it that are quite different.

The files and directories that are made available via CernVM-FS are always located
in a subdirectory of ``/cvmfs``, and are provisioned via a network of servers that
can basically be viewed as web servers since only outgoing ***HTTP*** connections are used.
This makes it easy to use CernVM-FS in environments that are protected by a strict firewall.

CernVM-FS is a ***read-only*** filesystem for those who access it; only those who administer it
are able to add or change its contents.

Internally, CernVM-FS uses content-addressable storage and Merkle trees in order to maintain file data and meta-data,
but the filesystem it exposes is a standard [POSIX filesystem](https://en.wikipedia.org/wiki/POSIX).


#### 1.1.2 Software distribution system

The primary use case of CernVM-FS is to easily ***distribute software*** around the world,
which is reflected in various ways in the features implemented by CernVM-FS.

It's worth highlighting that with *software* we actually mean ***software installations***,
that is the files that collectively form a usable instance of an application, tool, or library.
This is in contrast with software *packages* (for example, RPMs), which are essentially bundles of files wrapped
together for easy distribution, and which need to be *installed* in order to provide a working instance of the
provided software.

Software installations have specific characteristics, such as often
involving lots of small files which are being opened and read as a whole regularly,
frequent searching for files in multiple directories, hierarchical structuring, etc.
CernVM-FS is heavily tuned to cater to this use case, with aggressive caching and reduction of latency,
for example via automatic file de-duplication and compression.


#### 1.1.3 Scalable and reliable

CernVM-FS was designed to be ***scalable and reliable***, with known deployments involving hundreds of millions
of files and many tens of thousands of clients. It was originally created to fulfill the software distribution needs of the [experiments at the Large Hadron Collider (LHC)](https://home.cern/science/experiments) at CERN.

The network of (web) servers that make a CernVM-FS instance accessible is constructed such that it is robust
against problems like network disconnects and hardware failures, and so it can be extended and tweaked on demand
for optimal performance.


More details are available in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-overview.html).

## 1.2 Terminology

Before we get our hands dirty, let's cover some of the terminology used by the CernVM-FS project.

The figure included below shows the different components of the CernVM-FS network:

* the central *Stratum 0* server which hosts the filesystem;
* the *Stratum 1* replica servers, and the associated *proxies*;
* the *client* accessing the filesystem provided via CernVM-FS.

<p align="center">
<img src="../img/cvmfs_network.png" alt="CernVM-FS network" width="700px"/>
</p>

#### 1.2.1 Clients

A ***client*** in the context of CernVM-FS is any system that mounts the filesystem.
This includes laptops or personal workstations who need access to the provided software installations,
but also High-Performance Computing (HPC) clusters, virtual machines running in a cloud environment, etc.

Clients only have *read-only* access to the files included in a CernVM-FS repository,
and are automatically notified when the contents of the filesystem has changed.

The filesystem that is mounted on a client (under ``/cvmfs``) is a virtual filesystem, in the sense that
*data is only (down)loaded when it is actually accessed* (and cached aggressively to ensure good performance).

Mounting a CernVM-FS repository on a client will be covered in the [first hands-on part of this tutorial](02_stratum0_client.md).
Extensive documentation on configuring a client is available in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-configure.html).

#### 1.2.2 Stratum 0 + repository

A CernVM-FS ***repository*** is an instance of a CernVM-FS filesystem. A repository is hosted on one
***Stratum 0*** server, which is the single authoritative source of content for the repository.
Multiple repositories can be hosted on the same Stratum 0 server.

The data in a repository is stored using a [content-addressable storage](https://en.wikipedia.org/wiki/Content-addressable_storage) (CAS) scheme.
All files written to a CernVM-FS repository must be converted into data chunks in the CAS store during the process of *publishing*,
which involves creating catalogs which represent directory structure and metadata, and splitting files into chunks, compressing them, calculating content hashes, etc.
Publishing is done on a dedicated release manager machine or *publisher* system which interfaces with the Stratum 0 server.

Read-write access to a CernVM-FS repository is only available on a Stratum 0 server or publisher
(the publisher and Stratum 0 can be the same system).
Write access is provided via a *union filesystem*, which overlays a writable scratch area and the read-only mount of the CernVM-FS repository.
Publishing is an atomic operation: adding or changing files in a repository is done
in a *transaction* that records and collectively commits a set of file system changes,
preventing partial or incomplete updates of the repository and ensuring that changes are either applied completely, or not at all.

In the [first hands-on part of this tutorial](02_stratum0_client.md)
we will guide you through the process of creating a CernVM-FS repository,
which is also covered in detail in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-repo.html).

The [3rd hands-on part of this tutorial](04_publishing.md) will focus on the publishing procedure
to update the contents of a CernVM-FS repository.

#### 1.2.3 Stratum 1 replica servers

A ***Stratum 1 replica server*** is a *standard web server* that provides a ***read-only mirror***
of a CernVM-FS repository served by a Stratum 0.

The main purpose of a Stratum 1 is to improve reliability and capacity of the CernVM-FS network,
by distributing load across multiple servers and allowing clients to fail over if one is unavailable, and to relieve the Stratum 0 from serving client requests.
Although clients can access a CernVM-FS repository via the Stratum 0, it is advisable to block external client access to the Stratum 0 with a firewall,
and instead rely on the Stratum 1 replica servers to provide client access.

There usually are multiple Stratum 1 servers in a CernVM-FS network, which are typically distributed across geographic regions.
A repository may be replicated to arbitrarily many Stratum 1 servers, but for reasons related to caching efficiency of HTTP proxies, it is best to use only a modest number of Stratum 1 servers (in the 5-10 range), not an excessive amount.
While it depends on the specific context and circumstances under consideration, a reasonable rule of thumb would be approximately one Stratum 1 per continent for a deployment that is global in scope, and one Stratum 1 per geographic region of a country for a deployment that is national in scope.

Stratum 1 servers enable clients to determine which Stratum 1 is geographically closest to connect to,
via the Geo API which uses a [GeoIP database](https://dev.maxmind.com/geoip/geoip2/geolite2/) that
translates IP addresses of clients to an estimated longitude and latitude.

Setting up a Stratum 1 replica server will be covered in the [second hands-on part of this tutorial](03_stratum1_proxies.md),
and is also covered in detail in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-replica.html).

#### 1.2.4 Squid proxies

To further extend the scalability and hierarchical caching model of CernVM-FS, another layer is used between end clients and Stratum 1 servers: forward caching HTTP proxies which reduce load on Stratum 1 servers and help reduce latency for clients.
[Squid cache](http://www.squid-cache.org/) is commonly used for this.
A Squid proxy caches content that has been accessed recently, and helps to reduce bandwidth and improve response times.

It is particularly important to have caching proxies at large systems like HPC clusters where many worker nodes are accessing the
CernVM-FS repository, and it is recommended to set up multiple Squid proxies for redundancy and capacity.

The [second hands-on part of this tutorial](03_stratum1_proxies.md) will also cover setting up a Squid proxy.
More details are available in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-squid.html).
