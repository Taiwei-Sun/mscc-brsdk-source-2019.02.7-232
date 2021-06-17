#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Microsemi::SignedImage;

my(%opts) = ();

getopts("vk:", \%opts);

# -k <string>  - HMAC key

my($image) = Microsemi::SignedImage->new($opts{k});

my($file) = $ARGV[0];

die "Provide file to read as input" unless(-f $file);

$image->fromfile($file) || die("Invalid image");

print "Image decoded OK\n";

if($opts{v}) {
    print "Image length = ", length($image->{data}), "\n";
    for my $tlv (@{$image->{tlv}}) {
        my($type, $id, $value) = @{$tlv};
        print
            $Microsemi::SignedImage::typename[$type], " ",
            $Microsemi::SignedImage::tlvname[$id], " ", $value, "\n";
    }
}
