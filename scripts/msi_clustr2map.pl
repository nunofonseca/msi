#!/usr/bin/env perl

# usage: fasta file cluster_info
$no = 0;
$clstr = "";
$representative="";
$nmembers=0;
$clusterfile=shift;

open(my $fi, '<', $clusterfile)
    or die "Could not open file '$clusterfile' $!";

$pick=0;
## input is the output of clstr_sort_by.pl from cdhit
## members of the cluster
my $members;
$nclusters=0;
my $member;
while(my $ll = <$fi>){
    ##$ll=$_;
    chomp($ll);    
    if ($ll =~ /^>/) {
	## new cluster
	if ( $nmembers > 0 ) {
	    @members_l = (split ' ', $members);
	    foreach  $member (@members_l) {
		print "$member\t$representative\n";
	    }
	}
	print STDERR "." if ( $nclusters % 1000 == 0 );
	$nclusters++;
	$nmembers=0;
	$members="";
	$representative="";
    } else {

	if ( $ll =~ /\*$/ ) {
	    $pick=1;
	}
	$ll=~s/\.\.\..*//;
	$ll=~s/.*\>/\>/;
	$ll=~s/^>//;
	$ll=~s/:.*//;
	if ( $pick >0 ) {
	    $representative=$ll;
	    $pick=0;
	}
	if ( $nmembers == 0 ) {
	    $members=$ll;
	} else {
	    $members=$members." ".$ll;
	}
	$nmembers++;	
    }
}

if ( $nmembers > 0 ) {
    @members_l = (split ' ', $members);
    foreach $member (@members_l) {
	print "$member\t$representative\n";
    }
}
