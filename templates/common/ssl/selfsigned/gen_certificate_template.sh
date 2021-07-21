#!/usr/bin/expect -f

#########################################################################################
# Generates in the current direcotry a cert.pem certificate file, using a RSA key.pem key
# with no password.
# The following labels have to be replaced before running with the appropriate values:
#
# SEDcountrySED
# SEDstate_or_provinceSED
# SEDcitySED
# SEDorganizationSED
# SEDunit_nameSED
# SEDcommon_nameSED
# SEDemail_addressSED
#########################################################################################

set force_conservative 0

if {$force_conservative} {
   set send_slow {1 .1}
   proc send {ignore arg} {
      sleep .1
      exp_send -s -- $arg
   }
}

set timeout -1
log_user 0
spawn openssl req -new -x509 -key key.pem -days 365 -sha256 -out cert.pem
match_max 100000
expect -exact ":"
send -- "SEDcountrySED\r"
expect -exact ":"
send -- "SEDstate_or_provinceSED\r"
expect -exact ":"
send -- "SEDcitySED\r"
expect -exact ":"
send -- "SEDorganizationSED\r"
expect -exact ":"
send -- "SEDunit_nameSED\r"
expect -exact ":"
send -- "SEDcommon_nameSED\r"
expect -exact ":"
send -- "SEDemail_addressSED\r"
send_user cert.pem
expect eof
