#!/usr/bin/php
<?

# $Header: /home/cvs/thundaural/server/getcoverart.php,v 1.2 2003/12/27 10:25:42 jukebox Exp $

includepath_add("/usr/local/lib/php");

$argv = $_SERVER['argv'];
$argc = $_SERVER['argc'];

$stderr = fopen("php://stderr", "w");

# getcoverart.php - get cover art for albums using Amazon's SOAP API.

	$me = array_shift($argv);

	if ($argc != 4) {
		fwrite($stderr, "Usage:\n$me <artist> <album> <outputfile>\n");
		exit;
	}

	$artist = array_shift($argv);
	$album = array_shift($argv);
	$outputfile = array_shift($argv);

	set_time_limit(0); # Run forever

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
	$fp = fopen($url, "r");
	$content = '';
	while(!feof($fp)) {
		$content .= fread($fp, 4096);
	}
	fclose($fp);
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
