#!/usr/bin/php
<?php

# getcoverart.php - get cover art for albums using Amazon's SOAP API.

# $Header: /home/cvs/thundaural/server/getcoverart.php,v 1.5 2004/03/26 08:12:41 jukebox Exp $

includepath_add("/usr/local/lib/php");

$argv = $_SERVER['argv'];
$argc = $_SERVER['argc'];

$stderr = fopen("php://stderr", "w");

	$me = array_shift($argv);

	if (ini_get('safe_mode')) {
		fwrite($stderr, "$me can not run in safe-mode\n");
		exit(1);
	}

	if (!ini_get('allow_url_fopen')) {
		fwrite($stderr, "$me needs access to fopen URLs\n");
		exit(1);
	}

	if ($argc != 4) {
		fwrite($stderr, "Usage:\n$me <artist> <album> <outputfile>\n");
		exit(1);
	}

	$artist = array_shift($argv);
	$album = array_shift($argv);
	$outputfile = array_shift($argv);

	set_time_limit(40); # lets hope this doesn't take more than 40 seconds

	require("AmazonSearch.php"); # Load Amazon Search object

	$keywords = "$artist $album";

	$getimages = array('ImageUrlSmall', 'ImageUrlMedium', 'ImageUrlLarge');

	$Tag = 'webservices-20'; # Set Amazon associates tag

	$Token = 'D1LC9BSUSX258V'; # duke123@memelody.com Set Amazon developer token

	$AS = new AmazonSearch($Token, $Tag, $Debug=false); # Create search object

	$results = $AS->DoKeywordSearch($keywords, $SearchType = 'heavy', 'music', 30);

	$artist = preg_replace('/\b(The|An|A)\b\s+/i', '', $artist);
	$artistre = preg_quote($artist, '/');
	$artistre = preg_replace('/\s+/', '.+', $artistre);

	$albumre = preg_quote($album, '/');
	$albumre = preg_replace('/\s+/', '.+', $albumre);

	foreach ($results as $r) {
		$pname = $r['ProductName'];
		#print "$pname => $albumre\n";
		if (!preg_match("/$albumre/i", $pname)) {
			continue;
		}
		$alist = $r['Artists'];
		foreach ($alist as $a) {
			if (preg_match("/$artistre/i", $a)) {
				#print "found match on '$a' against /$artistre/\n";
				$images = array();
				# $context = stream_context_create(array('http'=>array('method'=>'GET', 'header'=>"Connection: close\r\n"))); only supported in PHP5
				# grab all the images
				foreach ($getimages as $i) {
					$images[] = get_image_file($r[$i]);
				}
				# use the largest one
				$longestimage = '';
				foreach ($images as $i) {
					if (strlen($i) > strlen($longestimage)) {
						$longestimage = $i;
					}
				}
				$out = fopen($outputfile, "w");
				fwrite($out, $longestimage);
				fclose($out);
				exit;
			}
		}
	}

# bah, file() isn't binary safe in this version of PHP
# and file_get_contents isn't available yet
function get_image_file($url) {
	$content = '';
	$fp = fopen($url, "r");
	if ($fp) {
		while(!feof($fp)) {
			$content .= fread($fp, 4096);
		}
		fclose($fp);
	}
	return $content;
}

function includepath_add($_addtopath) {
	$_x = ini_get('include_path');
	$_x = explode(':', $_x);
	if (!in_array($_addtopath, $_x)) {
		$_x[] = $_addtopath;
		ini_set('include_path', join(':', $_x));
	}
}


?>
