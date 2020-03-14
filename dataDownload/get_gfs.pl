#!/usr/bin/perl -w
# w. ebisuzaki CPC/NCEP/NWS/NOAA 10/2006
#
# simple script to download gfs files
# inspired by Dan Swank's get-narr.pl script
# this script uses the tecnique described in
#     https://www.cpc.ncep.noaa.gov/products/wesley/fast_downloading_grib.html
#
# arguments:  action YYYYMMDDHH HR0 HR1 DHR VAR_LIST LEV_LIST DIRECTORY
#
#   action = inv  (display inventory of 1st file)
#            data (get data)
#
#   HR0, HR1, DHR: forecast hour parameters
#            do f_hour = HR0, HR1, DHR                                  (fortran)
#            for (f_hour = HR1; f_hour <= HR1; f_hour = f_hour + DHR)   (C)
#
#   VAR_LIST:   list of variable separated by colons, blanks replaced by underscore
#            ex.  HGT:TMP:OZONE
#   LEV_LIST:   list of levesl separated by colons, blanks replaced by underscore
#            ex.  500_mb:sfc
#
#   DIRECTORY:  name of the directory in which to place the files
#
# v1.0  10/2006  who is going to find the first bug?
# v1.0a 10/2006  better help page
# v2.0beta  10/2006  no need for egrep, get_inv.pl and get_grib.pl
# v2.0beta2  10/2006  no need for egrep, get_inv.pl and get_grib.pl
# v2.0beta3  10/2006  update messages, ignore case on matches
# v2.0 1/2009 J.M. Berg: no need for OUTDIR for inventory
# v2.0.1 1/2011 change URL to http://nomads.ncep.noaa.gov
# v2.0.2 10/2012 set check for bad year to > 2030
# v2.1 1/2015 NCO change gfs naming conventions: added $FHR3, updated URLs
# v2.1.2 5/2017 quote left brace, required by new versions of perl
# v2.1.3 12/2018 conversion to https
# v2.1.4 12/2018 changed URLs to https
# v2.1.5 6/2019 changed URLs, help page
#
#------------ user customization section -----------------------------------------

# location of curl
$curl="curl";
$inv='.idx';
$grb='';

# the URLs of the inventory and grib must be defined by $URL$inv and $URL$grb
# symbolic variables supported YYYY MM DD HH FHR (forecast hour), FHR3 (3 digit forecast hour)
#
# grib2 files from operational nomads server
#
# 1x1 degree GFS
$URL='https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.$YYYY$MM$DD/$HH/gfs.t${HH}z.pgrb2.1p00.f${FHR3}';
# 0.5x0.5 degree GFS
# $URL='https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.$YYYY$MM$DD/$HH/gfs.t${HH}z.pgrb2.0p50.f${FHR3}';
# 0.25 x 0.25 degree GFS
# $URL='https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.$YYYY$MM$DD/$HH/gfs.t${HH}z.pgrb2.0p25.f${FHR3}';

#  if you want a 1/4 degree grid .. you should learn to use grib-filter
#  grib-filter will give regional subset and save downloading time
#  see  www.cpc.ncep.noaa.gov/products/wesley/scripting_grib_filter.html
#
# grib2 files from www.ftp.ncep.noaa.gov (not operational)
# $URL='https://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.$YYYY$MM$DD/$HH/gfs.t${HH}z.pgrb2.1p00.f${FHR3}';
#

# if insecure web server, $insecure='k';
$insecure='';
#$insecure='-k';

# the windows dos prompt often has problems with pipes, slower code code to avoid pipes
$windows='thankfully no';
# $windows='yes';


#------------- guts of script ---------------------------------------------------
$version="2.1.8";
if ($#ARGV != 7) {
  print "get_gfs.pl $version get GFS forecasts from nomads.ncep.noaa.gov\n";
  print "\nget_gfs.pl action YYYYMMDDHH HR0 HR1 DHR VAR_LIST LEV_LIST DIRECTORY\n\n";
  print "   action = inv  (display inventory of first data file)\n";
  print "            data (get data)\n";
  print "   YYYYMMDDHH: starting time of the forecast in UTC (Coordinated Universal Time)\n";
  print "   HR0, HR1, DHR: forecast hour parameters\n";
  print "      fortran: do f_hour = HR0, HR1, DHR\n";
  print "      C: for (f_hour = HR0; f_hour <= HR1; f_hour += DHR)\n";
  print "      enumerate forecast hours from HR0 to HR1 by increments fo DHR\n";
  print "   VAR_LIST: list of variable separated by colons, blanks replaced by underscore or all\n";
  print "      ex.  HGT:TMP:OZONE, all\n";
  print "   LEV_LIST:   list of levels separated by colons, blanks replaced by underscore or all\n";
  print "      ex.  500_mb:sfc, all\n";
  print "      Note: APCP has both 0-M hour acc fcst and N-N hour acc fcst in the GFS,\n";
  print "         to get the 0-N hour acc fcst, set LEV_LIST to '0-'\n";
  print "   DIRECTORY:  name of the directory in which to place the output files\n";
  print "   To see the available variables and levels in a particular file, display the inventory\n";
  print "\n                   EXAMPLES\n\n Displaying an inventory\n\n";
  print "       get_gfs.pl inv 2018123100 0 0 0 all all .\n\n";
  print " Downloading 500 hPa Height and Temp 0/3/6 hours forecasts to current directory\n\n";
  print "       get_gfs.pl data 2018123100 0 6 3 HGT:TMP 500_mb .\n\n";
  print " Downloading APCP 6/18 hours forecasts to current directory\n\n";
  print "       get_gfs.pl data 2018123000 6 18 6 APCP all .   *downloads 2 types of APCP\n";
  print "       get_gfs.pl data 2018123000 6 18 6 APCP 0- .    *downloads 0-N hour APCP (1 or 2 time)\n\n";
  print " Of course the date code will have to be current.\n";
  print "\nDec 30, 2018: This script has the current https URLs for the 1.0, 0.5 and 0.25\n";
  print " degree GFS forecasts. To change, to a different resolution GFS forecasts,\n";
  print "select the desired \$URL definition.\n";
  print "  This program can be used for other forecasts on nomads.ncep.noaa.gov by\n";
  print "changing the URL in this perl script. This program uses the partial\n";
  print "downloading techinque.\n";
  print "   https://www.cpc.ncep.noaa.gov/products/wesley/fast_downloading_grib.html\n";
  print "\nTo get user-defined regional subsets of the GFS forecast from the\n";
  print "nomads.ncep.noaa.gov server, use the grib_filter facility. \n"; 
  print "This is more useful for high-resolution grids.\n";
  exit(8);
}

$action = $ARGV[0];
$time = $ARGV[1];
$hr0=$ARGV[2];
$hr1=$ARGV[3];
$dhr=$ARGV[4];
$VARS=$ARGV[5];
$LEVS=$ARGV[6];
$OUTDIR = $ARGV[7];

$YYYY = substr($time,0,4);
$MM = substr($time,4,2);
$DD = substr($time,6,2);
$HH = substr($time,8,2);

# check values

if ($action ne 'data' && $action ne 'inv') {
   print "action must be inv or data, not $action\n";
   exit(8);
}

if ($YYYY < 2006 || $YYYY > 2040) {
   print "bad date (year) code $time\n";
   exit(8);
}
if ($MM < 1 || $MM > 12) {
   print "bad date (month) code $time\n";
   exit(8);
}
if ($DD < 1 || $DD > 31) {
   print "bad date (day) code $time\n";
   exit(8);
}
if ($HH < 0 || $HH > 23) {
   print "bad date (hour) code $time\n";
   exit(8);
}
if ($hr0 == $hr1) {
   $dhr = 3;
}

if ($dhr != 3 && $dhr != 6 && $dhr != 12 && $dhr != 24) {
   print "dhr must be 3, 6, 12 or 24, not $dhr\n";
   exit(8);
}

if ($hr0 > $hr1) {
   print "hr0 needs to be <= hr1\n";
   exit(8);
}
if ($dhr <= 0) {
   print "dhr needs to be > 0\n";
   exit(8);
}
if (! -d $OUTDIR && $action ne 'inv') {
   print "Directory $OUTDIR does not exist\n";
   exit(8);
}

$VARS =~ tr/:_/| /;
if( $VARS =~ m/ALL/ig ) { $VARS = "."; }
else { $VARS = ":($VARS):"; }

$LEVS =~ tr/:_/| /;
if( $LEVS =~ m/ALL/ig ) { $LEVS = "."; }
else { $LEVS = ":($LEVS)" ; }

$URL =~ s/\$YYYY/$YYYY/g;
$URL =~ s/\$\{YYYY\}/$YYYY/g;
$URL =~ s/\$MM/$MM/g;
$URL =~ s/\$\{MM\}/$MM/g;
$URL =~ s/\$DD/$DD/g;
$URL =~ s/\$\{DD\}/$DD/g;
$URL =~ s/\$HH/$HH/g;
$URL =~ s/\$\{HH\}/$HH/g;

$output = '';

$fhr=$hr0;
while ($fhr <= $hr1) {
   if ($fhr <= 9) { $fhr="0$fhr"; }
   $fhr3=$fhr;
   if ($fhr <= 99) { $fhr3="0$fhr"; }
   $url = $URL;
   $url =~ s/\$FHR3/$fhr3/g;
   $url =~ s/\$\{FHR3\}/$fhr3/g;
   $url =~ s/\$FHR/$fhr/g;
   $url =~ s/\$\{FHR\}/$fhr/g;
   $file = $url;
   $file =~ s/^.*\///;

   #
   # read the inventory
   #    $line[] = wgrib inventory,  $start[] = start of record (column two of $line[])
   #

   if ($windows eq 'yes') {
      $err = system("$curl $insecure -f -s $url$inv -o $OUTDIR/$file.tmp");
      $err = $err >> 8;
      if ($err) {
         print STDERR "error code=$err,  problem reading $url$inv\n";
         sleep(10);
         exit(8);
      }
      open (In, "$OUTDIR/$file.tmp");
   }
   else {
      open (In, "$curl $insecure -f -s $url$inv |");
   }

   $n=0;
   while (<In>) {
      chomp;
      $line[$n] = $_;
      s/^[^:]*://;
      s/:.*//;
      $start[$n] = $_;
      $n++;
   }
   close(In);
   if ($n == 0) {
       print STDERR "Problem reading file $url$inv\n";
       sleep(10);
       exit(8);
   }

   #
   # find end of record: $last[]
   #

   $lastnum = $start[$n-1];
   for ($i = 0; $i < $n; $i++) {
      $num = $start[$i];
      if ($num < $lastnum) {
         $j = $i + 1;
         while ($start[$j] == $num) { $j++; }
         $last[$i] = $start[$j] - 1;
      }
      else {      
         $last[$i] = '';
      }
   }
    
   if ($action eq 'inv') {
      for ($i = 0; $i < $n; $i++) {
         print "$line[$i]:range=$start[$i]-$last[$i]\n";
      }
      exit(0);
   }

   #
   # make the range field for Curl
   #

   $range = '';
   $lastfrom = '';
   $lastto = '-100';
   for ($i = 0; $i < $n; $i++) {
      $_ = $line[$i];
      if (/$LEVS/i && /$VARS/i) {
         $from=$start[$i];
         $to=$last[$i];

         if ($lastto + 1 == $from) {
            $lastto = $to;
         }
         elsif ($lastto ne $to) {
            if ($lastfrom ne '') {
               if ($range eq '') { $range = "$lastfrom-$lastto"; }
               else { $range = "$range,$lastfrom-$lastto"; }
            }
            $lastfrom = $from;
            $lastto = $to;
        }
      }
   }
   if ($lastfrom ne '') {
      if ($range eq '') { $range="$lastfrom-$lastto"; }
      else { $range="$range,$lastfrom-$lastto"; }
   }

   if ($range ne '') {
      $err = system("$curl $insecure -f -v -s -r \"$range\" $url$grb -o $OUTDIR/$file.tmp");
      $err = $err >> 8;
      if ($err != 0) {
         print STDERR "error in getting file $err $url$grb\n";
         sleep(20);
         exit $err;
      }
      rename "$OUTDIR/$file.tmp", "$OUTDIR/$file";
      $output = "$output $OUTDIR/$file";
   }
   else {
      print "no matches (no download) for $file\n";
   }
   $fhr += $dhr;
}
print "\n\nfinished download\n\n$output\n";
exit(0);
