<?php

/**
 * All _GET and _POST variables into your PHP application should be whitelist verified. 
 * This means you only allow certain characters for any input. Do not use blacklisting 
 * (how can you be sure you have listed all the 'bad' characters, especially with UTF-8?).
 * */

// an error occurred
function do_err($naddr, $nmsg)
{
    if ($naddr == "") {
        exit();
    }
    
    header('Location: ' . $naddr . '=' . $nmsg);
    exit();
}

// a standard error occurred
function do_std_err($nmsg)
{
    header('Location: /public/error.php?err=' . $nmsg);
    exit();
}

// check a text input is the correct length
// min, max -1 to ignore
function check_text_input($var, $min, $max, $errname, $erraddr)
{
    $ret = $var;
    
    if ((! ($min == - 1)) && (strlen($ret) < $min)) {
        do_err($erraddr, $errname . " too short");
    }
    
    if ((! ($max == - 1)) && (strlen($ret) > $max)) {
        do_err($erraddr, $errname . " too long");
    }
    
    return $ret;
}

// check a numeric value lies within a range
// min, max -1 to ignore
function check_num_input($var, $min, $max, $errname, $erraddr)
{
    $ret = $var;
    
    if (! is_numeric($ret)) {
        do_err($erraddr, $errname . " not a number");
    }
    
    if ((! ($min == - 1)) && ($ret < $min)) {
        do_err($erraddr, $errname . " min is " . $min);
    }
    
    if ((! ($max == - 1)) && ($ret > $max)) {
        do_err($erraddr, $errname . " max is " . $max);
    }
    
    return $ret;
}

// ajax version of text size checker
// min, max -1 to ignore
function check_text_input_ajax($var, $min, $max, $errname, $erraddr)
{
    $ret = $var;
    
    if ((! ($min == - 1)) && (strlen($ret) < $min)) {
        return false;
    }
    
    if ((! ($max == - 1)) && (strlen($ret) > $max)) {
        return false;
    }
    
    return $ret;
}

// ajax version of numeric range checker
// min, max -1 to ignore
function check_num_input_ajax($var, $min, $max)
{
    $ret = $var;
    
    if (! is_numeric($ret)) {
        return false;
    }
    
    if ((! ($min == - 1)) && ($ret < $min)) {
        return false;
    }
    
    if ((! ($max == - 1)) && ($ret > $max)) {
        return false;
    }
    
    return $ret;
}

// check a string exists in a string array
function check_text_input_in_array($var, $arr, $errname, $erraddr)
{
    $ret = $var;
    if (! (in_array($ret, $arr))) {
        do_err($erraddr, $errname . " not found");
    }
    
    return $ret;
}

// checks a string only contains chars from the array within
// returns original string if legal, or "Illegal Input" if not
function check_legal_chars($ns)
{
    $legal=array("q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", 
        "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m", "Q", "W", "E", "R", 
        "T", "Y", "U", "I", "O", "P", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Z", 
        "X", "C", "V", "B", "N", "M", " ", 
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", 
        "!", "@", "$", "*", "(", ")", ":", ";", "+", "-", "?" );
    
    $s = $ns;
    
    for ($i = 0; $i < count($legal); $i ++) {
        $s = str_replace($legal[$i], "", $s);
    }
    
    if ($s == "") {
        return $ns;
    }
    
    return "Illegal Input";
}

// seed the generator
function makerandseed()
{
    list ($usec, $sec) = explode(' ', microtime());
    
    return (float) $sec + ((float) $usec * 100000);
}

// return a password of length $nlength from the $legal array
function makepassword($nlength)
{
    $legal=array("q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", 
        "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m", "Q", "W", "E", "R", 
        "T", "Y", "U", "I", "O", "P", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Z", 
        "X", "C", "V", "B", "N", "M", 
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0");
    
    $ret = "";
    srand(makerandseed());
    
    for ($i = 0; $i < $nlength; $i ++) {
        $rnd = rand(0, 61);
        $ret .= $legal[$rnd];
    }
    
    return $ret;
}

// encrypt a string with aes
function aes_encrypt($data) {
    global $global_aeskey;
    $key = pack('H*', $global_aeskey);
    // Generate an initialization vector
    $iv = openssl_random_pseudo_bytes(openssl_cipher_iv_length('aes-256-cbc'));
    // Encrypt the data using AES 256 encryption in CBC mode using our encryption key and initialization vector.
    $encrypted = openssl_encrypt($data, 'aes-256-cbc', $key, 0, $iv);
    // The $iv is just as important as the key for decrypting, so save it with our encrypted data using a unique separator (::)
    return base64_encode($encrypted . '::' . $iv);
}

// decrypt an aes encrypted string
function aes_decrypt($data) {
    global $global_aeskey;
    $key = pack('H*', $global_aeskey);
    // To decrypt, split the encrypted data from our IV - our unique separator used was "::"
    list($encrypted_data, $iv) = explode('::', base64_decode($data), 2);
    return openssl_decrypt($encrypted_data, 'aes-256-cbc', $key, 0, $iv);
}

// example function to send mail
// by inserting into the sendemails table
function sendemail($nuserID, $nto, $nsubject, $nmessage)
{
    global $global_sendemailfrom;
    
    // check not bouncer or complainer
    $result = doSQL("select emailbounce, emailcomplaint from users where userID=?;", $nuserID) or do_std_err("Error getting mail details");
   
    if (! is_array($result)) {
        do_std_err("Error getting mail details");
    }
  
    if ($result[0]['emailbounce'] > 0) {
        do_std_err("Email has Bounced previous emails");
    }
  
    if ($result[0]['emailcomplaint'] > 0) {
        do_std_err("Email has Complained about previous emails");
    }
  
    // send
    $emsg = $nmessage . "\n\nThanks\n";
    $result = doSQL("insert into sendemails (userID, sendto, sendfrom, sendsubject, sendmessage) values (?, ?, ?, ?, ?)", $nuserID, $nto, $global_sendemailfrom, $nsubject, $emsg) or do_std_err("Error sending mail");
}

// use the Google lib to check a recaptcha
function checkrecaptcha($naddr, $nresponse)
{
    require_once ('autoload.php');
    global $global_recaptcha_privatekey;
    $privatekey = $global_recaptcha_privatekey;

    $recaptcha = new \ReCaptcha\ReCaptcha($privatekey);
    $resp = $recaptcha->verify($nresponse, $naddr);

    if (! $resp->isSuccess()) {
        return $resp->getErrorCodes();
    }

    return "";
}

?>