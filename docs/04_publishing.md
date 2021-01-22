# 4. Publishing

The previous sections were mostly about setting up the CernVM-FS infrastructure. Now that all the components for hosting and accessing your own CernVM-FS repository are in place, it is time to really start using it.
In this section we will give some more details about add files to your repository, which is referred to as *publishing*.

## 4.1 Transactions

As we already showed in the [first hands-on part of this tutorial](02_stratum0_client.md),
the easiest way to add files to your repository is by starting a transaction on your Stratum 0 server
and then publishing the changes.

By default, your repository directory under `/cvmfs` is read-only, but by a transaction makes the directory writable for the user that is owner of the repository. This is done by creating a union filesystem in the background
with a writable overlay.

To start a transaction, run:

```bash
cvmfs_server transaction repo.organization.tld
```

While the transaction is "open", you can make changes to your repository.

Once you are done with making changes, be sure to change your working directory to somewhere outside of the
repository (otherwise you will get an error), and publish your changes using:
```bash
cvmfs_server publish repo.organization.tld
```

You can always abort a transaction, which will undo all the non-published modifications:
```bash
cvmfs_server abort repo.organization.tld
```

After publishing or aborting a transaction, your repository will again be read-only.

### 4.1.1 Ingesting tarballs

When you need to compile software that you want to add to your repository, you may want to do the actual
compilation on a different system than your Stratum 0, and copy the resulting installation as a tarball
to your Stratum 0.

Instead of manually starting a transaction, extracting the tarball and then publishing it,
the `cvmfs_server` command offers a more efficient method for directly publishing the contents of a tarball:
```bash
cvmfs_server ingest -b /some/path repo.organization.tld -t mytarball.tar
```
The `-b` option expects the relative location in your repository where the contents of the tarball,
specified with `-t`, should be extracted.

So in this case the tarball gets extracted to `/cvmfs/repo.organization.tld/some/path`.
Note that passing '`/`' to the `-b` option does not work
in CernVM-FS versions prior to 2.8.0 (see [here](https://github.com/cvmfs/cvmfs/pull/2581)).

In case you have a compressed tarball, you can use an appropriate decompression tool and write the output to `stdout`.
This output can then be piped to `cvmfs_server` command while passing '`-`' to the `-t` option. For example, for a `.tar.gz` file:
```bash
gunzip -c mytarball.tar.gz | cvmfs_server ingest -b /some/path -t -
```


## 4.2 Tags

By default, a newly published version of the repository will automatically get a **tag** with a timestamp in its name. This allows you to revert back to earlier versions.
You can also set your own tag name and/or description upon publication:
```bash
cvmfs_server publish -a example_tag -m "Example description" repo.organization.tld
```

The `tag` subcommand for `cvmfs_server` allows you to create (`-a`), remove (`-r`), inspect (`-i`), or list (`-l`) tags of your repository, e.g.:
```
cvmfs_server tag -a "v1.0" repo.organization.tld
cvmfs_server tag -l repo.organization.tld
```

With the `rollback` subcommand you can revert back to an earlier version. By default, this will be the previous version, but with `-t` you can specify a specific tag to revert to:
```
cvmfs_server rollback -t "v0.5" repo.organization.tld
```

## 4.3 Catalogs

All metadata about files in your repository is stored in a file **catalog**, which is a SQLite database. When a client accesses the repository for the first time, it first needs to retrieve this catalog. Only then it can start fetching the files it actually needs. Clients also need to regularly check for new versions of the repository, and redownload the catalog if it has changed.

As this catalog can quickly become quite large when you start adding more and more files (think millions), just having a single one would cause significant overhead.  In order to keep them small, you can make use of **nested catalogs** by having several catalogs for different subtrees of your repository. All metadata for that part of the subtree will not be part of the main catalog anymore, and clients will only download the catalogs for the subtree(s) they are trying to access.

The general recommendation is to have more than 1,000 and fewer than 200,000 files and directories per (nested) catalog, and to bundle the files/directories that are often accessed together. For instance, it may make sense to provide a catalog per software installation directory, especially if different software versions or
configurations of software are located in their own separate subdirectory (as is common with a software installation
tool like [EasyBuild](https://easybuild.io)).

Making nested catalogs manually can be done in two ways, which we will describe in more detail.

### 4.3.1 `.cvmfscatalog` files

By adding an (empty, hidden) file named `.cvmfscatalog` into a directory of your repository, each following publish operation will automatically generate a nested catalog for the entire subtree in that directory. You can put these files at as many levels as you like, but do keep the recommendations mentioned above w.r.t. file and directory count in mind.

### 4.3.2 `.cvmfsdirtab` file

Instead of creating `.cvmfscatalog` files, you can also add a (hidden) file named `.cvmfsdirtab` to the root of your repository. In this file you can specify a list of relative directory paths (they all start from the root of your repository) that should get a nested catalog. You can also use wildcards to specify patterns and automatically include future contents, and use exclamation marks to exclude paths from a nested catalog.

As an example, assume you have a typical HPC software module tree in your repository with the following
structure (relative to the root of the repository):
```
software
├─ software/app1
│  ├─ software/app1/1.0
│  ├─ software/app1/2.0
├─ software/app2
│  ├─ software/app2/20201201
│  ├─ software/app2/20210125
modules
├─ modules/app1
│  ├─ modules/app1/1.0.lua
│  ├─ modules/app1/2.0.lua
├─ modules/all/app2
│  ├─ modules/app2/20201201.lua
│  ├─ modules/app2/20210125.lua
```

For this repository the `.cvmfsdirtab` file may look like:
```
# Nested catalog for each version of each application
/software/*/*
# One nested catalog for all software directories
/software

# One nested catalog containing for all module files
/modules
```

After you have added this file to your repository, you should see automatically generated `.cvmfscatalog` files in all the specified directories (note that you can still place additional ones manually as well). You can also run `cvmfs_server list-catalogs` to get a full list of all the nested catalogs.

One final note: if you use a `.cvmfsdirtab` file, a tarball ingestion using the `cvmfs_server ingest` command
[will currently (in CernVM-FS 2.8.0) not automatically create the nested catalogs](https://sft.its.cern.ch/jira/browse/CVM-1968).
You will need to do another (empty) transaction right after the ingestion to trigger the creation of the nested catalogs.


## Exercise
We prepared a tarball that contains a tree with dummy software installations. You can find the tarball at:
TODO: INSERT DETAILS

- Insert this tarball to a directory named `software` in your repository using the `ingest` subcommand (i.e. without actually extracting the tarball);
- Note that you get some warnings about the catalog containing too many entries;
- Fix the catalog issue by adding a `.cvmfsdirtab` file to the root of your repo, which automatically makes a catalog for each software installation directory;
- Make sure that the warning is gone when you publish this `.cvmfsdirtab` file. Instead, you may see a message about the catalog being defragmented (because lots of entries were cleaned up).
