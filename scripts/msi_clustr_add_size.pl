#!/usr/bin/env perl


$no = 0;
$clstr = "";
$representative="";
$nmembers=0;
$nreads=0;
$file2update=shift;
$pick=0;
while(<>){
    chomp;
    $ll=$_;
    if ($ll =~ /^>/) {
	## new cluster
	if ( $nmembers > 0 ) {
	    print "$representative:members=$nmembers:size=$nreads\n";
	    `sed -i 's/^$representative/$representative:members=$nmembers:size=$nreads/' $file2update`;
	}
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
	}
	$nreads+=$size;
    }
}

if ( $nmembers > 0 ) {
    print "$representative:members=$nmembers:size=$nreads\n";
    `sed -i 's/^$representative/$representative:members=$nmembers:size=$nreads/' $file2update`;
}

