<?php



/**
* transport class for sending/receiving data via HTTP and HTTPS
* NOTE: PHP must be compiled with the CURL extension for HTTPS support
*
* @author   Dietrich Ayala <dietrich@ganx4.com>
* @version  $Id: class.soap_transport_http.php,v 1.1 2004/01/08 08:45:28 jukebox Exp $
* @access public
*/
class soap_transport_http extends nusoap_base {

	var $url = '';
	var $uri = '';
	var $scheme = '';
	var $host = '';
	var $port = '';
	var $path = '';
	var $request_method = 'POST';
	var $protocol_version = '1.0';
	var $encoding = '';
	var $outgoing_headers = array();
	var $incoming_headers = array();
	var $outgoing_payload = '';
	var $incoming_payload = '';
	var $useSOAPAction = true;
	var $persistentConnection = false;
	var $ch = false;	// cURL handle
	
	/**
	* constructor
	*/
	function soap_transport_http($url){
		$this->url = $url;
		
		$u = parse_url($url);
		foreach($u as $k => $v){
			$this->debug("$k = $v");
			$this->$k = $v;
		}
		
		// add any GET params to path
		if(isset($u['query']) && $u['query'] != ''){
            $this->path .= '?' . $u['query'];
		}

		// set default port
		if(!isset($u['port'])){
			if($u['scheme'] == 'https'){
				$this->port = 443;
			} else {
				$this->port = 80;
			}
		}

		$this->uri = $this->path;
		
		// build headers
		$this->outgoing_headers['User-Agent'] = $this->title.'/'.$this->version;
		$this->outgoing_headers['Host'] = $this->host.':'.$this->port;
		$this->outgoing_headers['Content-Type'] = 'text/xml; charset='.$this->soap_defencoding;
	}
	
	function connect($connection_timeout=0,$response_timeout=30){
	  if ($this->scheme == 'http') {
		// use persistent connection
		if($this->persistentConnection && is_resource($this->fp)){
			if (!feof($this->fp)) {
				$this->debug('Re-use persistent connection');
				return true;
			}
			fclose($this->fp);
			$this->debug('Closed persistent connection at EOF');
		}
		
		// set timeout
		if($connection_timeout > 0){
			$this->fp = fsockopen( $this->host, $this->port, $this->errno, $this->error_str, $connection_timeout);
		} else {
			$this->fp = fsockopen( $this->host, $this->port, $this->errno, $this->error_str);
		}
		
		// test pointer
		if(!$this->fp) {
			$this->debug('Couldn\'t open socket connection to server '.$this->url.', Error: '.$this->error_str);
			$this->setError('Couldn\'t open socket connection to server: '.$this->url.', Error: '.$this->error_str);
			return false;
		}
		
		// set response timeout
		socket_set_timeout( $this->fp, $response_timeout);
		
		$this->debug('socket connected');
		return true;
	  } else if ($this->scheme == 'https') {
		if (!extension_loaded('curl')) {
			$this->setError('CURL Extension, or OpenSSL extension w/ PHP version >= 4.3 is required for HTTPS');
			return false;
		}
		$this->debug('connect using http');
		// init CURL
		$this->ch = curl_init();
		// set url
		$hostURL = ($this->port != '') ? "https://$this->host:$this->port" : "https://$this->host";
		// add path
		$hostURL .= $this->path;
		curl_setopt($this->ch, CURLOPT_URL, $hostURL);
		// set other options
		curl_setopt($this->ch, CURLOPT_HEADER, 1);
		curl_setopt($this->ch, CURLOPT_RETURNTRANSFER, 1);
		// encode
		// We manage this ourselves through headers and encoding
//		if(function_exists('gzuncompress')){
//			curl_setopt($this->ch, CURLOPT_ENCODING, 'deflate');
//		}
		// persistent connection
		if ($this->persistentConnection) {
			// The way we send data, we cannot use persistent connections, since
			// there will be some "junk" at the end of our request.
			//curl_setopt($this->ch, CURL_HTTP_VERSION_1_1, true);
			$this->persistentConnection = false;
			$this->outgoing_headers['Connection'] = 'close';
		}
		// set timeout
		if ($connection_timeout != 0) {
			curl_setopt($this->ch, CURLOPT_TIMEOUT, $connection_timeout);
		}
		// recent versions of cURL turn on peer/host checking by default,
		// while PHP binaries are not compiled with a default location for the
		// CA cert bundle, so disable peer/host checking.
//curl_setopt($this->ch, CURLOPT_CAINFO, 'f:\php-4.3.2-win32\extensions\curl-ca-bundle.crt');		
		curl_setopt($this->ch, CURLOPT_SSL_VERIFYPEER, 0);
		curl_setopt($this->ch, CURLOPT_SSL_VERIFYHOST, 0);
		$this->debug('cURL connection set up');
		return true;
	  } else {
		$this->setError('Unknown scheme ' . $this->scheme);
		$this->debug('Unknown scheme ' . $this->scheme);
		return false;
	  }
	}
	
	/**
	* send the SOAP message via HTTP
	*
	* @param    string $data message data
	* @param    integer $timeout set timeout in seconds
	* @return	string data
	* @access   public
	*/
	function send($data, $timeout=0) {
		
		$this->debug('entered send() with data of length: '.strlen($data));
		
		// make connnection
		if(!$this->connect($timeout)){
			return false;
		}
		
		// send request
		if(!$this->sendRequest($data)){
			return false;
		}
		
		// get response
		if(!$data = $this->getResponse()){
			return false;
		}
		
		$this->debug('end of send()');
		return $data;
	}


	/**
	* send the SOAP message via HTTPS 1.0 using CURL
	*
	* @param    string $msg message data
	* @param    integer $timeout set timeout in seconds
	* @return	string data
	* @access   public
	*/
	function sendHTTPS($data, $timeout=0) {
		return $this->send($data, $timeout);
	}
	
	/**
	* if authenticating, set user credentials here
	*
	* @param    string $user
	* @param    string $pass
	* @access   public
	*/
	function setCredentials($username, $password) {
		$this->outgoing_headers['Authorization'] = ' Basic '.base64_encode($username.':'.$password);
	}
	
	/**
	* set the soapaction value
	*
	* @param    string $soapaction
	* @access   public
	*/
	function setSOAPAction($soapaction) {
		$this->outgoing_headers['SOAPAction'] = $soapaction;
	}
	
	/**
	* use http encoding
	*
	* @param    string $enc encoding style. supported values: gzip, deflate, or both
	* @access   public
	*/
	function setEncoding($enc='gzip, deflate'){
		$this->protocol_version = '1.1';
		$this->outgoing_headers['Accept-Encoding'] = $enc;
		$this->outgoing_headers['Connection'] = 'close';
		$this->persistentConnection = false;
		set_magic_quotes_runtime(0);
		// deprecated
		$this->encoding = $enc;
	}
	
	/**
	* set proxy info here
	*
	* @param    string $proxyhost
	* @param    string $proxyport
	* @param	string $proxyusername
	* @param	string $proxypassword
	* @access   public
	*/
	function setProxy($proxyhost, $proxyport, $proxyusername = '', $proxypassword = '') {
		$this->uri = $this->url;
		$this->host = $proxyhost;
		$this->port = $proxyport;
		if ($proxyusername != '' && $proxypassword != '') {
			$this->outgoing_headers['Proxy-Authorization'] = ' Basic '.base64_encode($proxyusername.':'.$proxypassword);
		}
	}
	
	/**
	* decode a string that is encoded w/ "chunked' transfer encoding
 	* as defined in RFC2068 19.4.6
	*
	* @param    string $buffer
	* @returns	string
	* @access   public
	*/
	function decodeChunked($buffer){
		// length := 0
		$length = 0;
		$new = '';
		
		// read chunk-size, chunk-extension (if any) and CRLF
		// get the position of the linebreak
		$chunkend = strpos($buffer,"\r\n") + 2;
		$temp = substr($buffer,0,$chunkend);
		$chunk_size = hexdec( trim($temp) );
		$chunkstart = $chunkend;
		// while (chunk-size > 0) {
		while ($chunk_size > 0) {
			$this->debug("chunkstart: $chunkstart chunk_size: $chunk_size");
			
			$chunkend = strpos( $buffer, "\r\n", $chunkstart + $chunk_size);
		  	
			// Just in case we got a broken connection
		  	if ($chunkend == FALSE) {
		  	    $chunk = substr($buffer,$chunkstart);
				// append chunk-data to entity-body
		    	$new .= $chunk;
		  	    $length += strlen($chunk);
		  	    break;
			}
			
		  	// read chunk-data and CRLF
		  	$chunk = substr($buffer,$chunkstart,$chunkend-$chunkstart);
		  	// append chunk-data to entity-body
		  	$new .= $chunk;
		  	// length := length + chunk-size
		  	$length += strlen($chunk);
		  	// read chunk-size and CRLF
		  	$chunkstart = $chunkend + 2;
			
		  	$chunkend = strpos($buffer,"\r\n",$chunkstart)+2;
			if ($chunkend == FALSE) {
				break; //Just in case we got a broken connection
			}
			$temp = substr($buffer,$chunkstart,$chunkend-$chunkstart);
			$chunk_size = hexdec( trim($temp) );
			$chunkstart = $chunkend;
		}
		return $new;
	}

	/*
	 *	Writes payload, including HTTP headers, to $this->outgoing_payload.
	 */
	function buildPayload($data) {
		// update content-type header since we may have changed soap_defencoding
		$this->outgoing_headers['Content-Type'] = 'text/xml; charset='.$this->soap_defencoding;
		// add content-length header
		$this->outgoing_headers['Content-Length'] = strlen($data);
		
		// start building outgoing payload:
		$this->outgoing_payload = "$this->request_method $this->uri HTTP/$this->protocol_version\r\n";

		// loop thru headers, serializing
		foreach($this->outgoing_headers as $k => $v){
			if($k == 'SOAPAction'){
				$v = '"'.$v.'"';
			}
			$this->outgoing_payload .= $k.': '.$v."\r\n";
		}
		
		// header/body separator
		$this->outgoing_payload .= "\r\n";
		
		// add data
		$this->outgoing_payload .= $data;
	}

	function sendRequest($data){
		// build payload
		$this->buildPayload($data);

	  if ($this->scheme == 'http') {
		// send payload
		if(!fputs($this->fp, $this->outgoing_payload, strlen($this->outgoing_payload))) {
			$this->setError('couldn\'t write message data to socket');
			$this->debug('couldn\'t write message data to socket');
			return false;
		}
		$this->debug('wrote data to socket');
		return true;
	  } else if ($this->scheme == 'https') {
		// set payload
		curl_setopt($this->ch, CURLOPT_CUSTOMREQUEST, $this->outgoing_payload);
		$this->debug('set cURL payload');
		return true;
	  }
	}
	
	function getResponse(){
		$this->incoming_payload = '';

	  if ($this->scheme == 'http') {
	    // loop until headers have been retrieved
	    $data = '';
	    while (!isset($lb)){

			// We might EOF during header read.
			if(feof($this->fp)) {
				$this->setError('server failed to send headers');
				return false;
			}

			$data .= fgets($this->fp, 256);
			$pos = strpos($data,"\r\n\r\n");
			if($pos > 1){
				$lb = "\r\n";
			} else {
				$pos = strpos($data,"\n\n");
				if($pos > 1){
					$lb = "\n";
				}
			}
			// remove 100 header
			if(isset($lb) && ereg('^HTTP/1.1 100',$data)){
				unset($lb);
				$data = '';
			}//
		}
		// store header data
		$this->incoming_payload .= $data;
		// process headers
		$header_data = trim(substr($data,0,$pos));
		$header_array = explode($lb,$header_data);
		$data = substr($data,$pos);
		$this->debug('cleaned data, stringlen: '.strlen($data));
		foreach($header_array as $header_line){
			$arr = explode(':',$header_line);
			if(count($arr) >= 2){
				$this->incoming_headers[strtolower(trim($arr[0]))] = trim($arr[1]);
			}
		}
		
		// loop until msg has been received
		$strlen = 0;
	    while ((isset($this->incoming_headers['content-length'])&&$strlen < $this->incoming_headers['content-length']) || !feof($this->fp)){
			$tmp = fread($this->fp, 8192);
			$strlen += strlen($tmp);
			$data .= $tmp;
		}
		
		$data = trim($data);
		$this->incoming_payload .= $data;
		$this->debug('received '.strlen($this->incoming_payload).' bytes of data from server');
		
		// close filepointer
		if(
			//(isset($this->incoming_headers['connection']) && $this->incoming_headers['connection'] == 'close') || 
			(! $this->persistentConnection) || feof($this->fp)){
			fclose($this->fp);
			$this->fp = false;
			$this->debug('closed socket');
		}
		
		// connection was closed unexpectedly
		if($this->incoming_payload == ''){
			$this->setError('no response from server');
			return false;
		}
		
		$this->debug('received incoming payload: '.strlen($this->incoming_payload));
	  } else if ($this->scheme == 'https') {
		// send and receive
		$this->debug('send and receive with cURL');
		$this->incoming_payload = curl_exec($this->ch);
		$data = $this->incoming_payload;

        $cErr = curl_error($this->ch);
		if ($cErr != '') {
        	$err = 'cURL ERROR: '.curl_errno($this->ch).': '.$cErr.'<br>';
			foreach(curl_getinfo($this->ch) as $k => $v){
				$err .= "$k: $v<br>";
			}
			$this->debug($err);
			$this->setError($err);
			curl_close($this->ch);
	    	return false;
		} else {
			//echo '<pre>';
			//var_dump(curl_getinfo($this->ch));
			//echo '</pre>';
		}
		// close curl
		$this->debug('No cURL error, closing cURL');
		curl_close($this->ch);
		
		// remove 100 header
		if (ereg('^HTTP/1.1 100',$data)) {
			if ($pos = strpos($data,"\r\n\r\n")) {
				$data = ltrim(substr($data,$pos));
			} elseif($pos = strpos($data,"\n\n") ) {
				$data = ltrim(substr($data,$pos));
			}
		}
		
		// separate content from HTTP headers
		if ($pos = strpos($data,"\r\n\r\n")) {
			$lb = "\r\n";
		} elseif( $pos = strpos($data,"\n\n")) {
			$lb = "\n";
		} else {
			$this->debug('no proper separation of headers and document');
			$this->setError('no proper separation of headers and document');
			return false;
		}
		$header_data = trim(substr($data,0,$pos));
		$header_array = explode($lb,$header_data);
		$data = ltrim(substr($data,$pos));
		$this->debug('found proper separation of headers and document');
		$this->debug('cleaned data, stringlen: '.strlen($data));
		// clean headers
		foreach ($header_array as $header_line) {
			$arr = explode(':',$header_line);
			$this->incoming_headers[strtolower(trim($arr[0]))] = trim($arr[1]);
		}
		if (strlen($data) == 0) {
			$this->debug('no data after headers!');
			$this->setError('no data present after HTTP headers.');
			return false;
		}
	  }

		// decode transfer-encoding
		if(isset($this->incoming_headers['transfer-encoding']) && strtolower($this->incoming_headers['transfer-encoding']) == 'chunked'){
			if(!$data = $this->decodeChunked($data)){
				$this->setError('Decoding of chunked data failed');
				return false;
			}
			//print "<pre>\nde-chunked:\n---------------\n$data\n\n---------------\n</pre>";
		}
		
		// decode content-encoding
		if(isset($this->incoming_headers['content-encoding']) && $this->incoming_headers['content-encoding'] != ''){
			if(strtolower($this->incoming_headers['content-encoding']) == 'deflate' || strtolower($this->incoming_headers['content-encoding']) == 'gzip'){
    			// if decoding works, use it. else assume data wasn't gzencoded
    			if(function_exists('gzuncompress')){
					//$timer->setMarker('starting decoding of gzip/deflated content');
					if($this->incoming_headers['content-encoding'] == 'deflate' && $degzdata = @gzuncompress($data)){
    					$data = $degzdata;
					} elseif($this->incoming_headers['content-encoding'] == 'gzip' && $degzdata = gzinflate(substr($data, 10))){	// do our best
						$data = $degzdata;
					} else {
						$this->setError('Errors occurred when trying to decode the data');
					}
					//$timer->setMarker('finished decoding of gzip/deflated content');
					//print "<xmp>\nde-inflated:\n---------------\n$data\n-------------\n</xmp>";
    			} else {
					$this->setError('The server sent deflated data. Your php install must have the Zlib extension compiled in to support this.');
				}
			}
		}
		
		if(strlen($data) == 0){
			$this->debug('no data after headers!');
			$this->setError('no data present after HTTP headers');
			return false;
		}
		
		// set decoded payload
		$this->incoming_payload = $header_data."\r\n\r\n".$data;
		return $data;
	}
	
	function usePersistentConnection(){
		if (isset($this->outgoing_headers['Accept-Encoding'])) {
			return false;
		}
		$this->protocol_version = '1.1';
		$this->persistentConnection = true;
		$this->outgoing_headers['Connection'] = 'Keep-Alive';
		return true;
	}
}

?>