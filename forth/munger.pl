#!/usr/bin/perl
# Perl 3 compatible version for MS-DOS


$filename = "kernel.map";

# Open the file
open(FH, $filename) || die "Cannot open file '$filename': $!\n";

# Process each line
while (<FH>) {
    # Match pattern: two hex values and a symbol
    if ((/\b([0-9A-Fa-f]+)\s+([0-9A-Fa-f]+)\s+(\w+)/) && (substr($', 0, 1) ne '.')) {
        $hex1 = $1;
        $hex2 = $2;
        $symbol = $3;

        $symbol =~ tr/a-z/A-Z/;
        $symbol =~ s/^_//;   # Remove leading underscore if present
        $symbol =~ s/_$//;   # Remove trailing underscore if present
        $hex1 =~ tr/a-f/A-F/;
	 
        # Print as #define with symbol and first hex value
        print "#define K_$symbol 0x$hex1\n";
    }
}

close(FH);
