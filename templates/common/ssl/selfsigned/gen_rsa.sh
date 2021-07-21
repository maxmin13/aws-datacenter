#!/usr/bin/expect -f

#########################################################################################
# Generates in the current directory a key.pem RSA key with password 'secret'
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
spawn openssl genrsa -des3 -out key.pem 1024
match_max 100000
expect -exact ":"
send -- "secret\r"
expect -exact ":"
send -- "secret\r"
send_user key.pem
expect eof
