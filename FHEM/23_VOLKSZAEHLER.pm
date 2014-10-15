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
################################################################
# $Id:$
################################################################
package main;

use strict;
use warnings;
use JSON;
use Time::Piece;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request;

sub
VOLKSZAEHLER_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = "VOLKSZAEHLER_Define";
  $hash->{AttrList}  = "delay loglevel:0,1,2,3,4,5,6 ".
    "stateS ".
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
  my $reading = $a[5]||"";
  my $delay = $a[6]||"";
  
  $attr{$name}{delay}=$delay if $delay;

  return "Wrong syntax: use define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <Wert:last/min/max/average/consumption> <poll-delay>" if(int(@a) != 7);

  $hash->{Host} = $host;
  $hash->{Host_Port} = $host_port; 
  $hash->{Channel} = $channel;
  $hash->{Reading} = $reading;
 
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
  
  my $delay=$attr{$name}{delay}||300;
  
  InternalTimer(gettimeofday()+$delay, "VOLKSZAEHLER_GetStatus", $hash, 0);

  if(!defined($hash->{Host_Port})) { return(""); }
  
  my $host_port = $hash->{Host_Port}||"";
  my $URL="http://".$host.":".$host_port."/middleware.php/data/".$channel.".json?from=".$delay."%20seconds%20ago&tuples=1";
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

  my $decoded = JSON->decode( $response->content );
  
  #used for debugging
  #print $response->content."\n";
  
  my $min = $decoded->{data}->{min}[1]||"";  
  my $min_at = $decoded->{data}->{min}[0]||0;
  $min_at = localtime($min_at/1000);
  my $max = $decoded->{data}->{max}[1]||"";  
  my $max_at = $decoded->{data}->{max}[0]||0;  
  $max_at = localtime($max_at/1000);
  my $average = $decoded->{data}->{average}||"";
  my $consumption = $decoded->{data}->{consumption}||"";
  my $from = $decoded->{data}->{from}||0;
  $from = localtime($from/1000);
  my $to = $decoded->{data}->{to}||0;
  $to = localtime($to/1000);
  my $last = $decoded->{data}->{tuples}[0][1]||"";
  my $last_at = $decoded->{data}->{tuples}[0][0]||0;
  $last_at = localtime($last_at/1000);
  my $state=$last||"";
  
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
  $hash->{READINGS}{$sensor1}{TIME} = $min_at->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{READINGS}{$sensor1}{VAL} = $min;
  
  my $sensor2="MAX";
  $hash->{READINGS}{$sensor2}{TIME} = $max_at->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{READINGS}{$sensor2}{VAL} = $max;
  
  my $sensor3="AVERAGE";
  $hash->{READINGS}{$sensor3}{TIME} = TimeNow();
  $hash->{READINGS}{$sensor3}{VAL} = $average;
  
  my $sensor4="LAST";
  $hash->{READINGS}{$sensor4}{TIME} = $last_at->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{READINGS}{$sensor4}{VAL} = $last;
    
  my $sensor5="FROM";
  $hash->{READINGS}{$sensor5}{TIME} = $from->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{READINGS}{$sensor5}{VAL} = "";
  
  my $sensor6="TO";
  $hash->{READINGS}{$sensor6}{TIME} = $to->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{READINGS}{$sensor6}{VAL} = "";
      
  DoTrigger($name, undef) if($init_done);
}

1;
