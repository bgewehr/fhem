fhem
====

My contribution to fhem for integration of volkszaehler.org (http://www.volkszaehler.org)

See http://www.fhemwiki.de/wiki/Volkszaehler for details!

forked from bgewehr.

New features since Version 0.2 from gitka:

No need to use the Volkszaehler middleware (database). Only vzlogger with enabled local HTTP-support is needed.
You can send your data to middleware or/and enable local HTTP-support.

## Definition in FHEM with middleware support:
    define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <Wert:last/min/max/average/consumption> <poll-delay>

## Definition in FHEM with local support with vzlogger.conf (see below):
    define <name> VOLKSZAEHLER <ip-address> <port-nr> <channel> <poll-delay> local
    define Strombezug VOLKSZAEHLER localhost 8080 180 60 local
    define Einspeisung VOLKSZAEHLER localhost 8080 280 60 local

## For local HTTP-support change your vzlogger.conf
see vzlogger.conf 

