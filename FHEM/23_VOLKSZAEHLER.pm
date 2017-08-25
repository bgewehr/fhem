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
  $hash->{AttrList}  = "delay period loglevel:0,1,2,3,4,5,6 ".
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
  my $reading = uc($a[5])||"";
  my $delay = $a[6]||"";
  my $period = $a[7]||$delay;
  
  $attr{$name}{delay}=$delay if $delay;
  $attr{$name}{period}=$period if $period;
  $attr{$name}{'event-on-change-reading'} = uc($reading);
  $attr{$name}{stateFormat} = uc($reading);

  return "Wrong syntax: use define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <Wert:last/min/max/average/consumption> <poll-delay> optional: <period>" if(int(@a) < 7);

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
  my $period=$attr{$name}{period}||$delay;
  
  #Log 0, $name.' Delay: '.$delay.' Period: '.$period;
  InternalTimer(gettimeofday()+$delay, "VOLKSZAEHLER_GetStatus", $hash, 0);

  if(!defined($hash->{Host_Port})) { return(""); }
  
  my $host_port = $hash->{Host_Port}||"";
  my $URL="http://".$host.":".$host_port."/middleware.php/data/".$channel.".json?from=".$period."%20seconds%20ago&tuples=1";
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
  #print $response->content."\n";
  #print Dumper($decoded);
 
  # my $count = $decoded->{data}->{rows}||0;
  # print $count, "\n";

  # $count = $count - 2;
  # print $count, "\n";
  
  if ($decoded->{data}) {

  my $min = $decoded->{data}->{min}[1]||0;  
  my $min_at = $decoded->{data}->{min}[0]||0;
  $min_at = localtime($min_at/1000);
  my $max = $decoded->{data}->{max}[1]||0;  
  my $max_at = $decoded->{data}->{max}[0]||0;  
  $max_at = localtime($max_at/1000);
  my $average = $decoded->{data}->{average}||0;
  my $consumption = $decoded->{data}->{consumption}||0;
  my $from = $decoded->{data}->{from}||0;
  $from = localtime($from/1000);
  my $to = $decoded->{data}->{to}||0;
  $to = localtime($to/1000);
  Log 5, "VOLKSZAEHLER_debug: $name $host_port ".$hash->{STATE}." -> ".$response->content."\n";
  my $last = 0;
  my $last_at = $to;
  my $state = 0;

  my @tuples =  $decoded->{data}->{tuples};
  my $tuplescount = @tuples;

  Log 5, "VOLKSZAEHLER_debug: $tuplescount @tuples"."\n";

  if  ($tuplescount > 0 && $decoded->{data}->{rows} > 0){
      $last = $decoded->{data}->{tuples}[-1][1]||0;
      $last_at = $decoded->{data}->{tuples}[-1][0]||0;
      $last_at = localtime($last_at/1000);
      $state = $last||0;
  };

  SELECT:{
  if ($reading eq "average"){$state = $average; last SELECT; }
  if ($reading eq "min"){$state = $min; last SELECT; }
  if ($reading eq "max"){$state = $max; last SELECT; }
  if ($reading eq "consumption"){$state = $consumption; last SELECT; }
  }
  
  
  Log 4, "VOLKSZAEHLER_GetStatus: $name $host_port ".$hash->{STATE}." -> ".$state;

  my $i;
  my $ts;

  readingsBeginUpdate($hash);
  $ts = localtime()->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{".updateTimestamp"} = $ts;
  
  readingsBulkUpdate($hash, "CONSUMPTION", $consumption );
  
  $i = $#{ $hash->{CHANGED} };
  $ts = $min_at->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{".updateTimestamp"} = $ts;
  readingsBulkUpdate($hash, "MIN", $min );
  $hash->{CHANGETIME}->[$#{ $hash->{CHANGED} }] = $ts if ($#{ $hash->{CHANGED} } != $i ); # only add ts if there is a event to
  
  readingsBulkUpdate($hash, "MIN_AT", $min_at->strftime('%Y-%m-%d %H:%M:%S'));
   
  $i = $#{ $hash->{CHANGED} };
  $ts = $max_at->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{".updateTimestamp"} = $ts;
  readingsBulkUpdate($hash, "MAX", $max );
  $hash->{CHANGETIME}->[$#{ $hash->{CHANGED} }] = $ts if ($#{ $hash->{CHANGED} } != $i ); # only add ts if there is a event to

  readingsBulkUpdate($hash, "MAX_AT", $max_at->strftime('%Y-%m-%d %H:%M:%S'));

  readingsBulkUpdate($hash, "AVERAGE", $average );

  $i = $#{ $hash->{CHANGED} };
  $ts = $last_at->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{".updateTimestamp"} = $ts;
  readingsBulkUpdate($hash, "LAST", $last );
  $hash->{CHANGETIME}->[$#{ $hash->{CHANGED} }] = $ts if ($#{ $hash->{CHANGED} } != $i ); # only add ts if there is a event to

  readingsBulkUpdate($hash, "LAST_AT", $last_at->strftime('%Y-%m-%d %H:%M:%S'));

  $i = $#{ $hash->{CHANGED} };
  $ts = $from->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{".updateTimestamp"} = $ts;
  readingsBulkUpdate($hash, "FROM", $from->strftime('%Y-%m-%d %H:%M:%S'));
  $hash->{CHANGETIME}->[$#{ $hash->{CHANGED} }] = $ts if ($#{ $hash->{CHANGED} } != $i ); # only add ts if there is a event to

  $i = $#{ $hash->{CHANGED} };
  $ts = $to->strftime('%Y-%m-%d %H:%M:%S');
  $hash->{".updateTimestamp"} = $ts;
  readingsBulkUpdate($hash, "TO", $to->strftime('%Y-%m-%d %H:%M:%S'));
  $hash->{CHANGETIME}->[$#{ $hash->{CHANGED} }] = $ts if ($#{ $hash->{CHANGED} } != $i ); # only add ts if there is a event to

  readingsEndUpdate($hash, 1);
}
}
1;
