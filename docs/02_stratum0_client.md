# Stratum 0 + client

In order to get started with CernVM-FS, the first thing you need is a Stratum 0 server. This is the central server that hosts your repositories and makes it available to other machines. There can be only one Stratum 0 server for each repository, and from a security perspective it is usually recommended to restrict the access to this machine. We will look more into that later; for now, we are going to set up a Stratum 0, make a repository, and connect from a client machine directly to the Stratum 0.

## Set up the Stratum 0

### Requirements
Due to the scalable design of CernVM-FS, the host of your Stratum 0 server does not need a lot of resources in terms of CPU cores and memory; just a few cores and a few gigabytes of memory should suffice. Besides this, you need plenty of space to store the contents of your repository. CernVM-FS uses `/var/spool/cvmfs` as scratch space while adding new files to the repository, and `/srv/cvmfs` as central repository storage location.
To change these locations, you can create either of the paths as a symbolic link to a different directory.

Furthermore, several (popular) Linux distributions are supported, see [these requirements](https://github.com/cvmfs-contrib/cvmfs-tutorial-2021/wiki/Notes#stratum-1--proxies) for a full list. We will only focus on CentOS in this tutorial.

CernVM-FS also offers support for hosting the repository contents in S3 compatible storage, but for this tutorial we will focus on storing the files locally. For this we need an Apache server on the host, and port 80 should be open.

### Installation
The installation of CernVM-FS is simple and only requires some packages to be installed. You can easily do this by adding the CernVM-FS repository and install the packages through your package manager:

```bash
sudo yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
sudo yum install -y epel-release
sudo yum install -y cvmfs cvmfs-server
```

Alternatively, you can download the packages from the [CernVM-FS downloads page](https://cernvm.cern.ch/fs/) and install them package manually; note that you need both the client and server package on your Stratum 0.

### Start Apache

Since the Stratum 0 is serving contents via HTTP, Apache needs to be running before we can make a repository. The Apache (`httpd`) package should have been installed already, as it is a dependency of the `cvmfs-server` package, so it can now be enabled (so that it always starts after a reboot) and started using:
```
sudo systemctl enable httpd
sudo systemctl start httpd
```

### Create a repository
Now that all required packages have been installed, it is time to create a repository. In the simplest way, this can be done by running the following command, which will make `$USER` the owner of the repository:
```bash
sudo cvmfs_server mkfs -o $USER repo.organization.tld
```

The full repository name, here `repo.organization.tld`, resembles a DNS name, but the `organization.tld` domain does not necessarily have to exist. It is recommended to give all the repositories belonging to the same project or organization the same `.organization.tld` domain here. This makes the client configuration much easier, also in case new repositories will be added later on.

### Repository keys

For each repository that you create, a set of keys will be generated in `/etc/cvmfs/keys`:
 - `repo.organization.tld.crt` -  the repository’s public key (encoded as X509 certificate);
 - `repo.organization.tld.key` - the repository's private key;
 - `repo.organization.tld.masterkey` - the repository's private master key;
 - `repo.organization.tld.pub` -  repository’s public master key (RSA).

The public master key is the one that is needed by clients in order to access the repository; we will need this later on. The private master key is used to sign a whitelist of known publisher certificates; this whitelist is, by default, valid for 30 days, so the signing has to be done regularly.

For now we are going to use one master key per repository, but in practice it is recommended to use the same master key for all repositories under a single domain, so that clients only need a single public key to access all repositories under this domain. We will explain this in more detail in the advanced section.
TODO: DO WE WANT TO EXPLAIN THIS?

### Add some files to the repository
A new repository automatically gets a file `new_repository` in its root (`/cvmfs/repo.organization.tld`). You can add more files by starting and publishing a transaction, which will be explained in more detail in a later section. For now it is enough to just run the following commands as root:

```bash
MY_REPO_NAME=repo.organization.tld

sudo cvmfs_server transaction ${MY_REPO_NAME}

# Now make some changes in /cvmfs/${MY_REPO_NAME},
# e.g. by adding files or directories.
# If you made $USER the owner of the repository, you can do this without sudo.

sudo cvmfs_server publish ${MY_REPO_NAME}
```

### Cronjob for resigning the whitelist
Each CernVM-FS repository has a whitelist containing fingerprints of certificates that are allowed to sign the repository. This whitelist has an expiration time of, by default, 30 days. This means that you regularly have to resign the whitelist. There are several ways to do this, see for instance [the page about master keys](https://cvmfs.readthedocs.io/en/stable/cpt-repo.html#sct-master-keys) in the documentation.

If you just keep the master key on our Stratum 0 server, you can set up a simple cronjob for resigning the whitelist. For instance, make a file `/etc/cron.d/cvmfs_resign` with the following content to do this every Monday at 11:00:
```
0 11 * * 1 root /usr/bin/cvmfs_server resign repo.organization.tld
```

### Remove a repository
An existing repository can be removed by running:
```
sudo cvmfs_server rmfs repo.organization.tld
```


## Set up a client
Accessing CernVM-FS repositories on a client machine involves three steps: installing the CernVM-FS client package, adding some configuration files for the repository you want to connect to, and finally run a CernVM-FS setup procedure that will mount the repository.

Since the client is going to pull in files over an HTTP connection, you need sufficient space for storing a local cache on the client machine. You can define the maximum size of your cache in the settings; the larger your cache is, the less often you have to pull in files again, and the faster your applications will start.
Typical client cache sizes range from 4GB to 50GB.
Note that you can add more cache layers by adding a proxy nearby your client; this will be covered in a later section.

### Installation
The installation is the same as for the Stratum 0, except that you only need the `cvmfs` package:

```bash
sudo yum install https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
sudo yum install -y cvmfs
```

### Configuration
Many popular/large organizations hosting CernVM-FS repositories offer a client package that you can install to do most of the configuration. For our repository, we are going to do this manually. All required configuration files will have to be stored somewhere under `/etc/cvmfs`. We will discuss them one by one, where we use `repo.organization.tld` as repository name, and hence `organization.tld` as domain.

#### /etc/cvmfs/keys/organization.tld/repo.organization.tld.pub
This file contains the public key of the repository you want to access. You can copy this file from your Stratum 0 server, where it should be stored under /etc/cvmfs/keys.

#### /etc/cvmfs/config.d/repo.organization.tld.conf
This file contains the main configuration for the repository you want to access, which should minimally contain the URL(s) of the Stratum 1 servers and the location of the public key. Because we do not have a Stratum 1 server yet, we are going to (mis)use our Stratum 0 as a Stratum 1. You should not do this in production!

A typical, minimal configuration should look as follows:
```
CVMFS_SERVER_URL="http://your-stratum0/cvmfs/@fqrn@"
CVMFS_PUBLIC_KEY="/etc/cvmfs/keys/organization.tld/repo.organization.tld.pub"
```
Note that the `CVMFS_SERVER_URL` should have the `/cvmfs/@fqrn`; the last part will automatically be replaced by the full name of your repository.

#### /etc/cvmfs/default.local
This file can be used for setting or overriding settings that are specific to your client machine. One required parameter is `CVMFS_HTTP_PROXY`, which should point to your local proxy that serves as a cache between your client(s) and the Stratum 1 server(s). Since we do not have a proxy yet, we are setting this to `DIRECT`, meaning that we connect directly to the Stratum 1:
```
CVMFS_HTTP_PROXY=DIRECT
```

You can also use this file to set a maximum size (in megabytes) for the cache, for instance:
```
CVMFS_QUOTA_LIMIT=50000
```

### Mount the repositories
When your configuration is complete, you can run the following command as root to mount the repository:
```
sudo cvmfs_config setup
```
This should not return any error message. If you do run into an issue, check out
[the debugging section on the Advanced topics page](05_advanced.md#debugging-issues).

## Browse the repository
Finally, we can try to access our repository on the client machine. Note that CernVM-FS uses `autofs`, which means that you may not see the repository when you do `ls /cvmfs`. Your repository will only be actually mounted when you access it, and may be unmounted after not using it for a while. So, the following should work and show the contents of your repository:
```
ls /cvmfs/repo.organization.tld
```



## Exercise

- Set up your own Stratum 0 on a virtual machine.
- Create a repository with a suitable name (`name.domain.tld`).
- Add a simple bash script to the repository, which, for instance, prints `Hello world!`.
- Install and configure the CernVM-FS client on another virtual machine, using the Stratum 0 as your Stratum 1 for now.
- Try to access your repository and run your bash script on the client.
