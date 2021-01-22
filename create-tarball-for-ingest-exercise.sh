#!/bin/bash

if [ $# -ne 1 ]; then
    echo "ERROR: Usage: $0 <target directory>" 2>&1
    exit 1
fi

set -e

WORKDIR=$1
FILES_PER_EXAMPLE_SUBDIR=80000

APP1=GROAPPLES
APP2=FlensorStream
APP3=arrr
APP4=OpenPHOAN

date
echo "creating ~$((3 * $FILES_PER_EXAMPLE_SUBDIR)) files..."

for path in intel/haswell amd/rome arm64/thunderx2; do
    mkdir -p $WORKDIR/$path/{modules,software}/{$APP1,$APP2,$APP3,$APP4}
    
    for version in 2019 2020.3 2020.5; do
      echo "-- dummy module file for $APP1/${version}" > $WORKDIR/$path/modules/$APP1/${version}.lua
      mkdir -p $WORKDIR/$path/software/$APP1/${version}/{bin,lib}
      for bin in $APP1.sh $APP1.exe ; do
          echo '!#/bin/bash' > $WORKDIR/$path/software/$APP1/${version}/bin/$bin
          echo "echo $APP1"  >> $WORKDIR/$path/software/$APP1/${version}/bin/$bin
          chmod a+x $WORKDIR/$path/software/$APP1/${version}/bin/$bin
      done
      for lib in lib$APP1.a lib$APP1.so; do
          echo "$lib"  >> $WORKDIR/$path/software/$APP1/${version}/lib/$lib
      done
    done
    for version in 1.2 1.7 2.1; do
      echo "-- dummy module file for $APP2/${version}" > $WORKDIR/$path/modules/$APP2/${version}.lua
      mkdir -p $WORKDIR/$path/software/$APP2/${version}/{bin,lib}
      for i in $(seq 1 5); do
        for bin in $APP2-$i.sh $APP2-$i.exe ; do
            echo '!#/bin/bash' > $WORKDIR/$path/software/$APP2/${version}/bin/$bin
            echo "echo $APP2-$i"  >> $WORKDIR/$path/software/$APP2/${version}/bin/$bin
            chmod a+x $WORKDIR/$path/software/$APP2/${version}/bin/$bin
        done
      done
      for i in $(seq 1 5); do
        for lib in lib$APP2-$i.a lib$APP2-$i.so; do
          echo "$lib"  >> $WORKDIR/$path/software/$APP2/${version}/lib/$lib
        done
      done
    done
    for version in 20190827 20200126; do
      echo "-- dummy module file for $APP3/${version}" > $WORKDIR/$path/modules/$APP3/${version}.lua
      mkdir -p $WORKDIR/$path/software/$APP3/${version}/{bin,lib}
      for i in $(seq 1 10); do
        for bin in $APP3-$i.sh $APP3-$i.exe ; do
            echo '!#/bin/bash' > $WORKDIR/$path/software/$APP3/${version}/bin/$bin
            echo "echo $APP3-$i"  >> $WORKDIR/$path/software/$APP3/${version}/bin/$bin
            chmod a+x $WORKDIR/$path/software/$APP3/${version}/bin/$bin
        done
      done
      for i in $(seq 1 10); do
        for lib in lib$APP3-$i.a lib$APP3-$i.so; do
          echo "$lib"  >> $WORKDIR/$path/software/$APP3/${version}/lib/$lib
        done
      done
    done
    for version in 1.2-3; do
        echo "-- dummy module file for $APP4/${version}" > $WORKDIR/$path/modules/$APP4/${version}.lua
        mkdir -p $WORKDIR/$path/software/$APP4/$version/{bin,lib,examples}
        for bin in $APP4.sh $APP4.exe ; do
          echo '!#/bin/bash' > $WORKDIR/$path/software/$APP4/${version}/bin/$bin
          echo "echo $APP1"  >> $WORKDIR/$path/software/$APP4/${version}/bin/$bin
          chmod a+x $WORKDIR/$path/software/$APP4/${version}/bin/$bin
        done
        for lib in lib$APP4.a lib$APP4.so; do
          echo "$lib"  >> $WORKDIR/$path/software/$APP4/${version}/lib/$lib
        done
        for subdir in basic advanced real_world; do
            mkdir -p $WORKDIR/$path/software/$APP4/$version/examples/$subdir
            for i in $(seq 1 $FILES_PER_EXAMPLE_SUBDIR); do
                echo $i > $WORKDIR/$path/software/$APP4/$version/examples/$subdir/${i}.txt
            done
        done
    done

done

date
echo "creating tarball..."

cd $WORKDIR
tar cfz ../${WORKDIR}.tar.gz *

date
