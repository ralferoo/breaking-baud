#!/bin/bash 
CLUT=build/lk.clut.png
SRC=originals/lk-20140413
DST=sequence/lightkeeper
COLOURS=4

mkdir -p build
mkdir -p $DST
rm -f $DST/*.gif
#( cd $SRC ; rm *.bmp ; unzip -D -o "LV_VAR_5.zip" ) 

FILES=( `ls $SRC/*.bmp |
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
