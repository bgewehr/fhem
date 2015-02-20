fhem
====

My contribution to fhem for integration of volkszaehler.org (http://www.volkszaehler.org)

See http://www.fhemwiki.de/wiki/Volkszaehler for details!

forked from bgewehr.

New features since Version 0.2 from gitka:

No need to use the Volkszaehler middleware (database). Only vzlogger with enabled local HTTP-support is needed.
You can send your data to middleware or/and enable local HTTP-support.

## Definition in FHEM with middleware support:
> define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <Wert:last/min/max/average/consumption> <poll-delay>

## Definition in FHEM with local support with vzlogger.conf (see below):
> define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <poll-delay> local
> define Strombezug VOLKSZAEHLER localhost 8080 180 60 local
> define Einspeisung VOLKSZAEHLER localhost 8080 280 60 local

## For local HTTP-support change your vzlogger.conf:
example:

>{
>"retry" : 30,			/* how long to sleep between failed requests, in seconds */
>"daemon": false ,		/* run periodically */
>"verbosity" : 5,		/* between 0 and 15 */
>//"log" : "/var/log/vzlogger.log",/* path to logfile, optional */
>"log" : "/home/pi/vzlogger.log",/* path to logfile, optional */
>
>"local" : {
>    "enabled" : true,	/* should we start the local HTTPd for serving live readings? */
>    "port" : 8080,		/* the TCP port for the local HTTPd */
>    "index" : true,		/* should we provide a index listing of available channels if no UUID was requested? */
>    "timeout" : 30,		/* timeout for long polling comet requests, 0 disables comet, in seconds */
>//    "buffer" : 30		/* default=600 how long to buffer readings for the local interface, in seconds */
>    "buffer" : -1		/* negative values: how many readings for the local interface */
>
>},
>
>"meters" : [
>    {
>    //example for Landis&Gyr D0-meter
>    "enabled" : true , // true, Beginn L&G 1
>    "protocol" : "d0", 
>    "baudrate" : 300,
>    "device" : "/dev/ttyAMA0",
>    "parity" : "7E1",
>    "pullseq" : "2f3f210d0a", // HEX Darstellung der Pullsequenz
>    "interval" : 30, // Wartezeit bis zum nächsten Pull
>    "channels": [{
>        "api" : "NULL" , // new api without middleware support
>        "uuid" : "180",
>        "identifier" : "1.8.0", /* Zählerstand Bezug */
>        "middleware" : "http://localhost",
>            }, {
>        "api" : "NULL" ,
>        "uuid" : "280",
>        "middleware" : "http://localhost",
>        "identifier" : "2.8.0", /* Zählerstand Netz Einspeisung */
>            }]
>
>    }]
>}
>