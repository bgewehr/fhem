################################################################
#
#  Copyright notice
#
#  (c) 2013 Bernd Gewehr
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  This copyright notice MUST APPEAR in all copies of the script!
#  
#  Changes:
#  14.02.15 optimizer   enable to query local vzlogger http daemon or middleware daemon
#                       Prerequisites in vzlogger.conf : 
#                       "local" : {
#                          "enabled" : true,
#                          "port" : 8080,
#                          "timeout" : 30,
#                          "buffer" : -1<-----//to get only one tuple
#
################################################################
# $Id:$
################################################################
package main;

use strict;
use warnings;
#use JSON::PP;
use JSON;
use Time::Piece;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
my $MODUL          = "VOLKSZAEHLER";
my $VOLKSZAEHLER_VERSION = "0.2";

sub
VOLKSZAEHLER_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = "VOLKSZAEHLER_Define";
  $hash->{AttrList}  = "delay loglevel:0,1,2,3,4,5,6 ".
    "stateS disable:0,1 ".
    $readingFnAttributes;
}

sub
VOLKSZAEHLER_Define($$)
{
  my ($hash, $def) = @_;
  my $name=$hash->{NAME}||"";
  my @a = split("[ \t][ \t]*", $def);

  my $host = $a[2]||"";
  my $host_port = $a[3]||"";
  my $channel = $a[4]||"";
  my $reading;
  my $delay;
  my $type;

#  return "Wrong syntax: use define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <Wert:last/min/max/average/consumption> <poll-delay>" if(int(@a) != 7);
#  return "Wrong syntax: use define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <type:middl/local> <buffer:-x (Anzahl tuples)/x (in Sekunden)> <poll-delay>" if(int(@a) != 7);
   
# Lösung mit gleicher Parameteranzahl:
    if ( (int(@a) == 7 ) && ( $a[6] ne "local" )) {
       # "defined for querying Volkszähler middleware";
       $reading = $a[5]||"";
       $delay = $a[6]||"";
       Log3 $name, 2, "New device $name with middleware support created";
    }
    elsif ( (int(@a) == 7 ) && ( $a[6] eq "local" )) {
       # "defined for querying local vzlogger http-daemon";
       $delay = $a[5]||"";
       $type = $a[6]||"";
       $reading = "last";
       Log3 $name, 2, "New device $name with local support created";
    }  
    else {
       return "Wrong syntax: use for middleware support: \n define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <Wert:last/min/max/average/consumption> <poll-delay> \n 
       or use for local HTTP support: \n define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <poll-delay> local";
    }
  $attr{$name}{delay}=$delay if $delay;
  
  $hash->{Host} = $host;
  $hash->{VERSION} = $VOLKSZAEHLER_VERSION;
  $hash->{Host_Port} = $host_port; 
  $hash->{Channel} = $channel;
  $hash->{Reading} = $reading;
  $hash->{Type} = $type;
 
  InternalTimer(gettimeofday(), "VOLKSZAEHLER_GetStatus", $hash, 0);
 
  return undef;
}

######################################

sub
VOLKSZAEHLER_GetStatus($)
{
  my ($hash) = @_;
  my $err_log='';

  my $name = $hash->{NAME}||"";
  my $host = $hash->{Host}||"";
  my $channel = $hash->{Channel}||"";
  my $reading = $hash->{Reading}||"";
  my $type = $hash->{Type}||"";
  my $URL="";
  
  my $delay=$attr{$name}{delay}||300;
  
  InternalTimer(gettimeofday()+$delay, "VOLKSZAEHLER_GetStatus", $hash, 0);

  if(!defined($hash->{Host_Port})) { return(""); }
  
  my $host_port = $hash->{Host_Port}||"";
  if ($type eq "local") { 
      $URL="http://".$host.":".$host_port."/".$channel;
      #evtl.auch buffer übergeben?
      #z.B. buffer = 100 : Die letzten 100 Sekunden übergeben. 
      #     buffer = -1 : Den letzten Wert/tuples übergeben.
  }
  else {
      $URL="http://".$host.":".$host_port."/middleware.php/data/".$channel.".json?from=".$delay."%20seconds%20ago&tuples=1";
  } 
  my $agent = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1, timeout => 25)||"";
  my $header = HTTP::Request->new(GET => $URL)||"";
  my $request = HTTP::Request->new('GET', $URL, $header)||"";
  my $response = $agent->request($request)||"";

  $err_log.= "Can't get $URL -- ".$response->status_line
                unless $response->is_success;

  if($err_log ne "")
  {
        Log GetLogLevel($name,2), "VOLKSZAEHLER ".$err_log;
        return("");
  }

  my $decoded = decode_json( $response->content );
  
  #used for debugging
  print "debug Info VOLKSZAEHLER content";
  print $response->content."\n";
  
  my ($average, $min, $max, $consumption, $state, $min_at, $max_at, $from, $to, $last, $last_at);
  
  if ($type eq "local") {
      #{ "version": "0.4.0", "generator": "vzlogger", "data": [ { "uuid": "180", "last": 1423958150541, "interval": 30, "protocol": "d0", "tuples": [ [ 1423958150541, 15094.700000 ] ] } ] }
      print Dumper($decoded); #only with: use Data::Dumper;
      #$last = %$decoded->{data}->{tuples}[0][1];
      # "Not a HASH reference" führt zu FHEM Absturz 
      $last = $decoded->{data}->[0]->{tuples}[0][1]||0;
      #print "\n last = $last \n";
      $last_at = $decoded->{data}->[0]->{tuples}[0][0]||0;
      $last_at = localtime($last_at/1000);
      #print "last_at =  $last_at \n";
      $state=$last||"";
  }
  else {
  #{"version":"0.3","data":{"uuid":"abc","from":1403006628278,"to":1403006750232,"min":[1403006750232,8278.1],"max":[1403006689218,8341.319],"average":8309.691,"consumption":281.5,"rows":3,"tuples":[[1403006689218,8341.319,1],[1403006750232,8278.1,1]]}}
     $min = $decoded->{data}->{min}[1]||"";  
     $min_at = $decoded->{data}->{min}[0]||0;
     $min_at = localtime($min_at/1000);
     $max = $decoded->{data}->{max}[1]||"";  
     $max_at = $decoded->{data}->{max}[0]||0;  
     $max_at = localtime($max_at/1000);
     $average = $decoded->{data}->{average}||"";
     $consumption = $decoded->{data}->{consumption}||"";
     $from = $decoded->{data}->{from}||0;
     $from = localtime($from/1000);
     $to = $decoded->{data}->{to}||0;
     $to = localtime($to/1000);
     $last = $decoded->{data}->{tuples}[0][1]||"";
     $last_at = $decoded->{data}->{tuples}[0][0]||0;
     $last_at = localtime($last_at/1000);
     $state=$last||"";
  
   }
  SELECT:{
     if ($reading eq "average"){$state = $average; last SELECT; }
     if ($reading eq "min"){$state = $min; last SELECT; } 
     if ($reading eq "max"){$state = $max; last SELECT; }
     if ($reading eq "consumption"){$state = $consumption; last SELECT; }
   }
  
  Log 4, "VOLKSZAEHLER_GetStatus: $name $host_port ".$hash->{STATE}." -> ".$state;

  my $text=$reading.": ".$state||"";
  
  $hash->{STATE} = substr($reading,0,1).": ".$state;
  $hash->{CHANGED}[0] = $text;
  
  my $sensor0="CONSUMPTION";
  $hash->{READINGS}{$sensor0}{TIME} = TimeNow();
  $hash->{READINGS}{$sensor0}{VAL} = $consumption;
   
  my $sensor1="MIN";
  $hash->{READINGS}{$sensor1}{TIME} = $min_at->strftime('%Y-%m-%d %H:%M:%S')||0 if (defined($min_at));
  $hash->{READINGS}{$sensor1}{VAL} = $min;
  
  my $sensor2="MAX";
  $hash->{READINGS}{$sensor2}{TIME} = $max_at->strftime('%Y-%m-%d %H:%M:%S')||0 if (defined($max_at));
  $hash->{READINGS}{$sensor2}{VAL} = $max;
  
  my $sensor3="AVERAGE";
  $hash->{READINGS}{$sensor3}{TIME} = TimeNow();
  $hash->{READINGS}{$sensor3}{VAL} = $average;
  
  my $sensor4="LAST";
  $hash->{READINGS}{$sensor4}{TIME} = $last_at->strftime('%Y-%m-%d %H:%M:%S')||0 if (defined($last_at));
  $hash->{READINGS}{$sensor4}{VAL} = $last;
    
  my $sensor5="FROM";
  $hash->{READINGS}{$sensor5}{TIME} = $from->strftime('%Y-%m-%d %H:%M:%S')||0 if (defined($from));
  $hash->{READINGS}{$sensor5}{VAL} = "";
  
  my $sensor6="TO";
  $hash->{READINGS}{$sensor6}{TIME} = $to->strftime('%Y-%m-%d %H:%M:%S')||0 if (defined($to));
  $hash->{READINGS}{$sensor6}{VAL} = "";
      
  DoTrigger($name, undef) if($init_done);
}

1;
