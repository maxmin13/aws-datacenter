#!/usr/bin/expect -f

#########################################################################################
# Creates a new no_pass_key.pem key with no password from a key.pem RSA key in the 
# current directory.
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
spawn openssl rsa -in key.pem -out no_pass_key.pem
match_max 100000
expect -exact ":"
send -- "secret\r"
send_user no_pass_key.pem
expect eof
