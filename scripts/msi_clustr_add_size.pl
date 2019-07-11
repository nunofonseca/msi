#!/usr/bin/env perl


# usage: fasta file cluster_info
$no = 0;
$clstr = "";
$representative="";
$nmembers=0;
$nreads=0;
$file2update=shift;
$clusterfile=shift;
#open(my $fh, '<:encoding(UTF-8)', $file2update)
open(my $fh, '<', $file2update)
    or die "Could not open file '$file2update' $!";

open(my $fi, '<', $clusterfile)
    or die "Could not open file '$clusterfile' $!";

$pick=0;
## input is the output of clstr_sort_by.pl from cdhit
## file2 update should be a fasta file (sequence lines should not be truncated - only one line per entry)
##
my %nreads_h;
my %nmembers_h;
$nclusters=0;
while(my $ll = <$fi>){
    ##$ll=$_;
    chomp($ll);    
    if ($ll =~ /^>/) {
	## new cluster
	if ( $nmembers > 0 ) {
	    $nmembers_h{"$representative"}=$nmembers;
	    $nreads_h{"$representative"}=$nreads;
	}
	print STDERR "." if ( $nclusters % 1000 == 0 );
	$nclusters++;
	$nmembers=0;
	$nreads=0;	    
	$representative="";
    } else {
	$nmembers++;	
	if ( $ll =~ /\*$/ ) {
	    $pick=1;
	}
	$ll=~s/\.\.\..*//;
	$ll=~s/.*\>/\>/;

	if ( $pick >0 ) {
	    $representative=$ll;
	    $pick=0;
	}
	$size=0;
	if ($ll =~ /:size=(\d+)$/) {
	    $size = $1;
	} else {
	    print STDERR "ERROR\n";
	    exit 1;
	}
	$nreads+=$size;
    }
}

if ( $nmembers > 0 ) {
    #print STDERR "$representative:members=$nmembers:size=$nreads\n";
    $nmembers_h{"$representative"}=$nmembers;
    $nreads_h{"$representative"}=$nreads;
    #`sed -i 's/^$representative/$representative:members=$nmembers:size=$nreads/' $file2update`;
}
##
print STDERR "Updating number of members and numbers of reads per cluster in $file2update\n";

print STDERR (scalar keys %nmembers_h)."\n";
print STDERR (scalar keys %nreads_h)."\n";

#for my $k (keys %nmembers_h) {
#    print "=members===$k=$nmembers_h{$k}\n";
#    print "=nreads===$k=$nreads_h{$k}\n";
#}
print STDERR "================================================================================\n";
#use strict;
#use warnings;
while (my $line = <$fh>) {
    chomp $line;
    if ($line =~ /^>/) {
	##
	## > is part of the representative sequence
	($representative, $rline) = split (/\s+/, $line, 2);
	$rline=~s/\s+/:/g;

	##print STDERR ">>>>>$representative<< ===== >>$rline<< \n";
	$nmembers=$nmembers_h{"$representative"};
	$nreads=$nreads_h{"$representative"};

	$representative=~s/\s+/:/g;
	print "$representative:$rline:members=$nmembers:size=$nreads\n";
	if ( $nreads eq "" || nmembers eq "") {
	    print STDERR "$representative not found in  stdin";
	    exit 1;
	}
	#else {
	#    print STDERR "Found!!!";	    
	#}

    } else {
	print "$line\n";
    }    
}
