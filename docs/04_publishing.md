# Publishing

The previous sections were mostly about setting up the infrastructure. Now that all the components for hosting and accessing your own CernVM-FS repositories are in place, it is time to really start using it.
In this section we will give some more details about publishing files.

## Transactions

As we already showed in a previous section, the easiest way to add files to your repository is by opening and publishing a transaction on your Stratum 0 server.
By default, your repository directory under `/cvmfs` is read-only, but by a transaction makes the directory writable for the user that is owner of the repository.
```
sudo cvmfs_server transaction repo.organization.tld
```

Once you are done with making changes, the changes can be published using:
```
sudo cvmfs_server publish repo.organization.tld
```

And you can always abort a transaction, which will undo all the non-published modifications:
```
sudo cvmfs_server abort repo.organization.tld
```

### Ingesting tarballs

When you need to compile software that you want to add to your repository, you may want to do the actual compilation on a different machine than your Stratum 0 and copy the resulting installation as a tarball to your Stratum 0. Instead of manually extracting the tarball and doing a transaction, the `cvmfs_server` command offers a more efficient method for directly publishing the contents of a tarball:
```
sudo cvmfs_server ingest -b /some/path repo.organization.tld -t mytarball.tar
```
The `-b` expects the relative location in your repository where the contents of the tarball, specified with `-t`, will be extracted. So, in this case, the tarball gets extracted to `/cvmfs/repo.organization.tld/some/path`. Note that passing `/` to `-b` does not work at the moment, but will be supported in a future release of CernVM-FS.

In case you have a compressed tarball, you can use an appropriate decompression tool and write the output to `stdout`.
This output can then be piped to `cvmfs_server` by setting `-t -`, e.g. for a `.tar.gz` file:
```
gunzip -c mytarball.tar.gz | sudo cvmfs_server ingest -b /some/path -t -
```


## Tags

By default, a newly published version of the repository will automatically get a tag with a timestamp in its name. This allows you to revert back to earlier versions.
You can also set your own tag name and/or description upon publication:
```
sudo cvmfs_server publish [-a tag name] [-m tag description] repo.organization.tld
```

The `tag` subcommand for `cvmfs_server` allows you to create (`-a`), remove (`-r`), inspect (`-i`), or list (`-l`) tags of your repository, e.g.:
```
sudo cvmfs_server tag -a "v1.0" repo.organization.tld
sudo cvmfs_server tag -l repo.organization.tld
```

With the `rollback` subcommand you can revert back to an earlier version. By default, this will be the previous version, but with `-t` you can specify a specific tag to revert to:
```
sudo cvmfs_server rollback -t "v0.5" repo.organization.tld
```

## Catalogs

## Homework
We prepared a tarball that contains a tree with dummy software installations. You can find the tarball at:
TODO: INSERT DETAILS

- Insert this tarball to a directory named `software` in your repository using the `ingest` subcommand;
- Note that you get some warnings about the catalog containing too many entries;
- Fix the catalog issue by adding a `.cvmfsdirtab` file to your repo, which automatically makes a catalog for each software installation;
