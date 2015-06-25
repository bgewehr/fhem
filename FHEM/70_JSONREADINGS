################################################################
#
#  Copyright notice
#
#  (c) 2015 Bernd Gewehr
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
my $decoded="";

use strict;
use warnings;
use JSON;
use Time::Piece;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request;

sub
JSONREADINGS_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = "JSONREADINGS_Define";
  $hash->{AttrList}  = "delay loglevel:0,1,2,3,4,5,6 ".
    "stateS ".
    $readingFnAttributes;
}

sub
JSONREADINGS_Define($$)
{
  my ($hash, $def) = @_;
  my $name=$hash->{NAME}||"";
  my @a = split("[ \t][ \t]*", $def);

  my $url = $a[2]||"";
  my $delay = $a[3]||"";
  
  $attr{$name}{delay}=$delay if $delay;

  return "Wrong syntax: use define <name> JSONREADINGS <url> <poll-delay>" if(int(@a) != 4);

  $hash->{Url} = $url;

  InternalTimer(gettimeofday(), "JSONREADINGS_GetStatus", $hash, 0);
 
  return undef;
}

######################################

sub
JSONREADINGS_GetStatus($)
{
  my ($hash) = @_;
  my $err_log='';

  my $name = $hash->{NAME}||"";
  my $URL = $hash->{Url}||"";
  my $delay=$attr{$name}{delay}||300;
  
  InternalTimer(gettimeofday()+$delay, "JSONREADINGS_GetStatus", $hash, 0);

  if(!defined($hash->{Url})) { return(""); }
  
  my $agent = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1, timeout => 25)||"";
  my $header = HTTP::Request->new(GET => $URL)||"";
  my $request = HTTP::Request->new('GET', $URL, $header)||"";
  my $response = $agent->request($request)||"";

  $err_log.= "Can't get $URL -- ".$response->status_line
                unless $response->is_success;

  if($err_log ne "")
  {
        Log GetLogLevel($name,2), "JSONREADINGS ".$err_log;
        return("");
  }

  my $decoded = decode_json( $response->content );
  
  #used for debugging
  #print $response->content."\n";
  
  readingsBeginUpdate($hash);
  
  toReadings($hash, $decoded);
  
  readingsEndUpdate($hash,1);
  
  DoTrigger($name, undef) if($init_done);
}

sub toReadings($$;$$)                                                                
{                                                                               
  my ($hash,$ref,$prefix,$suffix) = @_;                                               
  $prefix = "" if( !$prefix );                                                  
  $suffix = "" if( !$suffix );                                                  
  $suffix = "_$suffix" if( $suffix );                                           
                                                                                
  if(  ref($ref) eq "ARRAY" ) {                                                 
    while( my ($key,$value) = each $ref) {                                      
      toReadings($hash,$value,$prefix.sprintf("%02i",$key+1)."_");                        
    }                                                                           
  } elsif( ref($ref) eq "HASH" ) {                                              
    while( my ($key,$value) = each $ref) {                                      
      if( ref($value) ) {                                                       
        toReadings($hash,$value,$prefix.$key.$suffix."_");                            
      } else {
      	  readingsBulkUpdate($hash, $prefix.$key.$suffix, $value);
      }                                                                         
    }                                                                           
  }                                                                             
}                                                                               
                                                                                
                                                                                
1;
