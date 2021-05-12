<?php
// when we upload to Production Environment,
// this is replaced with emailsendfrom
// which must be a verified SES email
$global_sendemailfrom = "SEDsend_email_fromSED";

// whether to use development or minified js and css
$global_minifyjscss = "SEDminifed_jscssSED";

// 0=don't require ssl 1=require ssl
// if required, non-ssl requests will be redirected to ssl in init.php
$global_require_ssl = "0";

// set UTC as the default time zone
date_default_timezone_set('UTC');

// the address of the standard error page
$stderr = "/public/error.php?err";

// these usernames are denied for signing up
$global_reserved_usernames = array("administrator","support","admin","security","website","site","company","error","warning","moderator","moderate","staff","employee");

// session times out after x seconds, eg 30 minutes = 1800 seconds
$global_sessionexpiry = 1800;

// session can at most last x seconds, eg 1 week = 604800 seconds
$global_sessionmaxtime = 604800;

// we are on aws, get from httpd.conf the id of this server
$global_serverid = $_SERVER['SERVERID'];

// the aeskey for session cookie encryption
$global_aeskey = $_SERVER['AESKEY'];

// the recaptcha private key (from aws/credentials/recaptcha.sh)
$global_recaptcha_privatekey = $_SERVER['RECAPTCHA_PRIVATEKEY'];

// the recaptcha public key (from aws/credentials/recaptcha.sh)
$global_recaptcha_publickey = $_SERVER['RECAPTCHA_PUBLICKEY'];

?>
