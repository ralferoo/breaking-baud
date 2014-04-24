#!/bin/bash 
CLUT=build/bin_renderin.clut.png
SRC=originals/bin_renderin-20140412
DST=sequence/bin_renderin
COLOURS=16

mkdir -p build
mkdir -p $DST
#( cd $SRC ; unrar -o- x steps)

FILES=( `ls $SRC/steps/*.gif |
perl -ne 'chop;s/\r//;$s=$_;$n++;$d=sprintf("%02d.gif",$n);system("convert \"$s\" build/$d");print STDERR "Mapping $_ to $d...\n";print "$d\n";'`)

LAST=${FILES[${#FILES[@]} - 1]}
echo "Making CLUT from ${LAST}"
convert build/$LAST -colors $COLOURS -unique-colors $CLUT

for i in "${FILES[@]}"
do
	echo "Remapping ${i}"
	convert build/$i -colors $COLOURS -remap $CLUT $DST/$i
done

for i in "${FILES[@]}"
do
	echo $DST/$i
done >$DST/build.done
