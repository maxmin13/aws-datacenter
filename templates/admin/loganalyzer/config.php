<?php
/*
	*********************************************************************
	* LogAnalyzer - http://loganalyzer.adiscon.com
	* -----------------------------------------------------------------
	* Main Configuration File
	*
	* -> Configuration need variables for the database connection
	*
	* Copyright (C) 2008-2010 Adiscon GmbH.
	*
	*********************************************************************
*/

// --- Avoid directly accessing this file! 
if ( !defined('IN_PHPLOGCON') ) {
	die('Hacking attempt');
	exit;
	}

$CFG['UserDBEnabled'] = false;
$CFG['UserDBServer'] = 'localhost';
$CFG['UserDBPort'] = 3306;
$CFG['UserDBName'] = 'loganalyzer'; 
$CFG['UserDBPref'] = 'logcon_'; 
$CFG['UserDBUser'] = 'root';
$CFG['UserDBPass'] = '';
$CFG['UserDBLoginRequired'] = false;
$CFG['UserDBAuthMode'] = 0;

$CFG['LDAPServer'] = '127.0.0.1';
$CFG['LDAPPort'] = 389;
$CFG['LDAPBaseDN'] = 'CN=Users,DC=domain,DC=local';
$CFG['LDAPSearchFilter'] = '(objectClass=user)';
$CFG['LDAPUidAttribute'] = 'sAMAccountName';
$CFG['LDAPBindDN'] = 'CN=Searchuser,CN=Users,DC=domain,DC=local';
$CFG['LDAPBindPassword'] = 'Password';

$CFG['MiscShowDebugMsg'] = 0;
$CFG['MiscDebugToSyslog'] = 0;
$CFG['MiscShowDebugGridCounter'] = 0;
$CFG["MiscShowPageRenderStats"] = 1;
$CFG['MiscEnableGzipCompression'] = 1;
$CFG['MiscMaxExecutionTime'] = 60;
$CFG['DebugUserLogin'] = 0;

$CFG['PrependTitle'] = "";
$CFG['ViewUseTodayYesterday'] = 1;
$CFG['ViewMessageCharacterLimit'] = 0;
$CFG['ViewStringCharacterLimit'] = 0;
$CFG['ViewEntriesPerPage'] = 100;
$CFG['ViewEnableDetailPopups'] = 0;
$CFG['ViewDefaultTheme'] = "default";
$CFG['ViewDefaultLanguage'] = "en";
$CFG['ViewEnableAutoReloadSeconds'] = 0;

$CFG['SearchCustomButtonCaption'] = "I'd like to feel sad";
$CFG['SearchCustomButtonSearch'] = "error";

$CFG['EnableContextLinks'] = 0;
$CFG['EnableIPAddressResolve'] = 0;
$CFG['SuppressDuplicatedMessages'] = 0;
$CFG['TreatNotFoundFiltersAsTrue'] = 0;
$CFG['PopupMenuTimeout'] = 3000;
$CFG['PhplogconLogoUrl'] = "";
$CFG['InlineOnlineSearchIcons'] = 1;
$CFG['UseProxyServerForRemoteQueries'] = "";
$CFG['HeaderDefaultEncoding'] = ENC_ISO_8859_1;

$CFG['InjectHtmlHeader'] = "";
$CFG['InjectBodyHeader'] = "";
$CFG['InjectBodyFooter'] = "";

$CFG['DefaultViewsID'] = "";

$CFG['Search'][] = array ( "DisplayName" => "Syslog Warnings and Errors", "SearchQuery" => "filter=severity%3A0%2C1%2C2%2C3%2C4&search=Search" );
$CFG['Search'][] = array ( "DisplayName" => "Syslog Errors", "SearchQuery" => "filter=severity%3A0%2C1%2C2%2C3&search=Search" );
$CFG['Search'][] = array ( "DisplayName" => "All messages from the last hour", "SearchQuery" => "filter=datelastx%3A1&search=Search" );
$CFG['Search'][] = array ( "DisplayName" => "All messages from last 12 hours", "SearchQuery" => "filter=datelastx%3A2&search=Search" );
$CFG['Search'][] = array ( "DisplayName" => "All messages from last 24 hours", "SearchQuery" => "filter=datelastx%3A3&search=Search" );
$CFG['Search'][] = array ( "DisplayName" => "All messages from last 7 days", "SearchQuery" => "filter=datelastx%3A4&search=Search" );
$CFG['Search'][] = array ( "DisplayName" => "All messages from last 31 days", "SearchQuery" => "filter=datelastx%3A5&search=Search" );

$CFG['Charts'][] = array ( "DisplayName" => "Top Hosts", "chart_type" => CHART_BARS_HORIZONTAL, "chart_width" => 400, "chart_field" => SYSLOG_HOST, "maxrecords" => 10, "showpercent" => 0, "chart_enabled" => 1 );
$CFG['Charts'][] = array ( "DisplayName" => "SyslogTags", "chart_type" => CHART_CAKE, "chart_width" => 400, "chart_field" => SYSLOG_SYSLOGTAG, "maxrecords" => 10, "showpercent" => 0, "chart_enabled" => 1 );
$CFG['Charts'][] = array ( "DisplayName" => "Severity Occurences", "chart_type" => CHART_BARS_VERTICAL, "chart_width" => 400, "chart_field" => SYSLOG_SEVERITY, "maxrecords" => 10, "showpercent" => 1, "chart_enabled" => 1 );
$CFG['Charts'][] = array ( "DisplayName" => "Usage by Day", "chart_type" => CHART_CAKE, "chart_width" => 400, "chart_field" => SYSLOG_DATE, "maxrecords" => 10, "showpercent" => 1, "chart_enabled" => 1 );

$CFG['DiskAllowed'][] = "/var/log/"; 
$CFG['DefaultSourceID'] = 'Source1';

$result=array();
$temp_result=array();

$log_dir="/var/log";

function find_all_files($dir)
{
    $root = scandir($dir);
    
    foreach($root as $value)
    {
        if($value === '.' || $value === '..') {
            continue;
        }

        if(is_file("$dir/$value")) {
            $result[] = "$dir/$value";
            continue 1;
        }

        $temp_result = find_all_files("$dir/$value");
       
        if(is_array($temp_result) && sizeof($temp_result) > 0)
        {
            foreach($temp_result as $value)
            {
                $result[]=$value;
            }
        }
    }
    return $result;
}

$files = find_all_files($log_dir);

$i=1;

foreach($files as $file)
{
   $file_source_name = substr($file, strlen($log_dir));

   $CFG['Sources']['Source'.$i]['ID'] = 'Source'.$i;
   $CFG['Sources']['Source'.$i]['Name'] = $file_source_name;
   $CFG['Sources']['Source'.$i]['ViewID'] = 'SYSLOG';
   $CFG['Sources']['Source'.$i]['SourceType'] = SOURCE_DISK;
   $CFG['Sources']['Source'.$i]['LogLineType'] = 'syslog';
   $CFG['Sources']['Source'.$i]['DiskFile'] = $file;

   $i=$i+1;
}


?>
