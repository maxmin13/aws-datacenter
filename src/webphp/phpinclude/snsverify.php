<?php

/*
 * Adapted from:
 *
 * http://sns-public-resources.s3.amazonaws.com/Verifying_Message_Signatures_4_26_10.pdf
 * https://forums.aws.amazon.com/thread.jspa?threadID=45518
 *
 * Verify SNS JSON message against Amazon certificate. Following message types can be verified:
 * SubscriptionConfirmation
 * Notification
 *
 * Region, account and one of topics[] must match the contents of the "TopicArn" included
 * in the message. Also, SigningCertURL's domain must end in ".amazonaws.com".
 *
 * Joni /2011
 */
function verify_sns($message, $region, $account, $topics)
{
    $msg = json_decode($message);
    // Check that region, account and topic match
    $topicarn = explode(':', $msg->TopicArn);
    if ($topicarn[3] != $region || $topicarn[4] != $account || ! in_array($topicarn[5], $topics)) {
        return false;
    }
    $_region = $topicarn[3];
    $_account = $topicarn[4];
    $_topic = $topicarn[5];

    // Check that the domain in message ends with '.amazonaws.com'
    if (! endswith(get_domain_from_url($msg->SigningCertURL), '.amazonaws.com')) {
        return false;
    }

    // Load certificate and extract public key from it
    $surl = $msg->SigningCertURL;
    $curlOptions = array(CURLOPT_URL => $surl,CURLOPT_VERBOSE => 1,CURLOPT_RETURNTRANSFER => 1,CURLOPT_SSL_VERIFYPEER => TRUE,CURLOPT_SSL_VERIFYHOST => 2);
    $ch = curl_init();
    curl_setopt_array($ch, $curlOptions);
    $cert = curl_exec($ch);
    $pubkey = openssl_get_publickey($cert);
    if (! $pubkey) {
        return false;
    }

    // Generate a message string for comparison in Amazon-specified format
    $text = "";
    if ($msg->Type == 'Notification') {
        $text .= "Message\n";
        $text .= $msg->Message . "\n";
        $text .= "MessageId\n";
        $text .= $msg->MessageId . "\n";
        if (isset($msg->Subject)) {
            if ($msg->Subject != "") {
                $text .= "Subject\n";
                $text .= $msg->Subject . "\n";
            }
        }
        $text .= "Timestamp\n";
        $text .= $msg->Timestamp . "\n";
        $text .= "TopicArn\n";
        $text .= $msg->TopicArn . "\n";
        $text .= "Type\n";
        $text .= $msg->Type . "\n";
    }
    elseif ($msg->Type == 'SubscriptionConfirmation') {
        $text .= "Message\n";
        $text .= $msg->Message . "\n";
        $text .= "MessageId\n";
        $text .= $msg->MessageId . "\n";
        $text .= "SubscribeURL\n";
        $text .= $msg->SubscribeURL . "\n";
        $text .= "Timestamp\n";
        $text .= $msg->Timestamp . "\n";
        $text .= "Token\n";
        $text .= $msg->Token . "\n";
        $text .= "TopicArn\n";
        $text .= $msg->TopicArn . "\n";
        $text .= "Type\n";
        $text .= $msg->Type . "\n";
    }
    else {
        return false;
    }

    // Get a raw binary message signature
    $signature = base64_decode($msg->Signature);

    // ..and finally, verify the message
    if (openssl_verify($text, $signature, $pubkey, OPENSSL_ALGO_SHA1)) {
        return true;
    }

    return false;
}

// http://stackoverflow.com/questions/619610/whats-the-most-efficient-test-of-whether-a-php-string-ends-with-another-string
function endswith($string, $test)
{
    $strlen = strlen($string);
    $testlen = strlen($test);
    if ($testlen > $strlen) {
        return false;
    }
    return substr_compare($string, $test, - $testlen) === 0;
}

// http://codepad.org/NGlABcAC
function get_domain_from_url($url, $max_node_count = 0)
{
    $return_value = '';
    $max_node_count = (int) $max_node_count;
    $url_parts = parse_url((string) $url);
    if (is_array($url_parts) && isset($url_parts['host']) && strlen((string) $url_parts['host']) > 0) {
        $return_value = (string) $url_parts['host'];
        if ($max_node_count > 0) {
            $host_parts = explode('.', $return_value);
            $return_parts = array();
            for ($i = $max_node_count; $i > 0; $i --) {
                $current_node = array_pop($host_parts);
                if (is_string($current_node) && $current_node !== '') {
                    $return_parts[] = $current_node;
                }
                else {
                    break;
                }
            }
            if (count($return_parts) > 0) {
                $return_value = implode('.', array_reverse($return_parts));
            }
            else {
                $return_value = '';
            }
        }
    }
    return $return_value;
}

?>