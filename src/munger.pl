#!/usr/bin/perl
# Perl 3 compatible version for MS-DOS

# Check if filename was provided

$filename = "KERNEL.MAP";

# Open the file
open(FH, $filename) || die "Cannot open file '$filename': $!\n";

# Process each line
while (<FH>) {
    # Match pattern: two hex values and a symbol
    # Adjust the regex pattern based on your specific format
    if (/\b([0-9A-Fa-f][0-9A-Fa-f])\s+([0-9A-Fa-f][0-9A-Fa-f])\s+(\w+)/) {
        $hex1 = $1;
        $hex2 = $2;
        $symbol = $3;

	chop($symbol);
       	$symbol =~ tr/a-z/A-Z/;
	$hex1 =~ tr/a-f/A-F/;
	 
        # Print as #define with symbol and first hex value
        print "#define K_$symbol 0x$hex1\n";
    }
}

close(FH);
