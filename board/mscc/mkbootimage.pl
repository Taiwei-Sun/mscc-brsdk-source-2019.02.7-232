#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;
use File::Spec;
use Getopt::Std;

use Microsemi::SignedImage;

# Default target CPU is MIPS
my(%opts) = ( 'T' => 2, );

getopts("T:C:k:o:", \%opts);

# -T <target>  - Target CPU 1 = ARM, 2 = MIPS
# -C <CHIP>    - CHIP type
# -k <string>  - HMAC key
# -o file      - Output file

my($chipid) = hex($opts{C});

# Construct output file
my ($fn) = shift(@ARGV) || die("Must provide input file");
die("$fn: $!") unless(-f $fn);

my($image) = Microsemi::SignedImage->new($opts{k});
$image->setfile($fn) || die("$fn: $!");

printf "Adding trailer: Arch %d, Chip %x\n", $opts{T}, $chipid;

my ($name,$path,$suffix) = fileparse($fn,qw(\.\w+));
my ($out) = File::Spec->catfile($path, $name . '.img');
$out = $opts{o} if($opts{o});

$image->add_tlv_dword(Microsemi::SignedImage::TLV_ARCH, $opts{T});
$image->add_tlv_dword(Microsemi::SignedImage::TLV_CHIP, $chipid);
$image->add_tlv_dword(Microsemi::SignedImage::TLV_IMGTYPE, Microsemi::SignedImage::TLV_IMGTYPE_BOOT_LOADER);

$image->writefile($out) || die("$out: $!");

print "Wrote $out\n";
