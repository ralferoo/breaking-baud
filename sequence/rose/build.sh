#!/bin/bash 
CLUT=build/rose
SRC=originals/rose-20140413
DST=sequence/rose
COLOURS=16

mkdir -p build
mkdir -p $DST
#( cd $SRC ; unzip -D -o "Rose 320x200.zip" )

FILES=( `ls $SRC/*.bmp |
perl -ne 'chop;s/\r//;$s=$_;$n++;$d=sprintf("%02d.gif",$n);system("convert \"$s\" build/$d");print STDERR "Mapping $_ to $d...\n";print "$d\n";'`)

LAST=`echo $FILES|tail -1`
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
