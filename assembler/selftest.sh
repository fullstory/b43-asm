#!/bin/bash

ASM="b43-asm"
DASM="b43-dasm"
SUM="sha1sum"
TMPDIR="/tmp"


if [ $# -ne 1 ]; then
	echo "b43-(d)asm trivial selftest"
	echo "This selftest will take the binary input file, disassemble"
	echo "it, assemble it and compare the two binaries."
	echo
	echo "Usage: $0 /path/to/binary"
	exit 1
fi
infile="$1"

if ! [ -r "$infile" ]; then
	echo "Can not read input binary $infile"
	exit 1
fi

rnd="$RANDOM"
asmfile="$TMPDIR/b43-asm-selftest-$rnd.asm"
outfile="$TMPDIR/b43-asm-selftest-$rnd.bin"

function cleanup
{
	rm -f "$asmfile"
	rm -f "$outfile"
}
cleanup


$DASM "$infile" "$asmfile"
err=$?
if [ $err -ne 0 ]; then
	echo "Disassembling FAILED: $err"
	cleanup
	exit 1
fi
$ASM "$asmfile" "$outfile"
err=$?
if [ $err -ne 0 ]; then
	echo "Assembling FAILED: $err"
	cleanup
	exit 1
fi

orig_sum="$($SUM "$infile" | cut -f1 -d ' ')"
err=$?
if [ $err -ne 0 ] || [ -z "$orig_sum" ]; then
	echo "Checksumming of input file failed: $err"
	cleanup
	exit 1
fi
out_sum="$($SUM "$outfile" | cut -f1 -d ' ')"
err=$?
if [ $err -ne 0 ] || [ -z "$out_sum" ]; then
	echo "Checksumming of reassembled file failed: $err"
	cleanup
	exit 1
fi
cleanup

echo "Input file checksum:    $orig_sum"
echo "Re-assembled checksum:  $out_sum"
echo

if [ "$orig_sum" != "$out_sum" ]; then
	echo "FAILURE: Checksums don't match!"
	exit 1
fi
echo "Checksums match"

exit 0
