<?
/*
 * AmazonSearch.php 
 *
 * A class which retrieves Amazon product information using SOAP.
 *
 * Requires the NuSphere NuSOAP library (nusoap.php).
 * (Available at http://dietrich.ganx4.com/nusoap/index.php)
 * Configure your PHP installation so that nusoap.php is on your
 * include path.
 */

/* Define constants */
define('WSDL_FILE',   'http://soap.amazon.com/schemas2/AmazonWebServices.wsdl');
define('TAG',         'webservices--20');
define('DEFAULT_MAX', 10);
define('MEGA_MAX',    999999);


/* Load SOAP package */
require_once('nusoap.php');

class AmazonSearch
{
  var $Client = null;
  var $Proxy  = null;
  var $Token  = '';
  var $Debug  = false;

  /*
   * AmazonSearch -
   *
   *	Constructor. The developer token must be supplied; the AssociateID
   *    is optional. If $Debug is true, then requests and responses are
   *	printed.
   */

  function AmazonSearch($Token, $AssociateID = TAG, $Debug = false)
  {
    /* Save developer token, associate ID, and debug flag */
    $this->Token       = $Token;
    $this->AssociateID = $AssociateID;
    $this->Debug       = $Debug;

    /* Create SOAP client */
    $this->Client = new soapclient(WSDL_FILE, true);
    //    print("Client created\n");

    /* Create proxy for client (contains methods per WSDL) */
    $this->Proxy = $this->Client->getproxy();
    //    print("Proxy created\n");
  }

  /*
   * _DoSearch - 
   *
   *	Internal function to perform a search using the given
   *	set of parameters. This function will perform multiple
   *	calls in order to return up to $Max results. If Max
   *	is 0 then it will return all matching results. 
   *	$TopLevelName is the name of the array item expected
   *	at the top level of the data returned by the SOAP call.
   *	If this is null then a single unnamed result is 
   *	expected.

   */

  function _DoSearch($Func, $Params, $Max, $TopLevelName)
  {
    /* Set a really high Max if unlimited results are desired */
    if ($Max == 0)
    {
      $Max = MEGA_MAX;
    }

    /* Start accumulating results */
    $Ret = array();

    /* Count pages */
    $Page = 1;

    /* Flag that we got results */
    $MorePages = true;

    if ($TopLevelName !== null)
    {
      /* Keep getting results until we have enough or there are no more */
      while ($MorePages && (count($Ret) < $Max))
      {
	/* Request proper page */
	$Params['page'] = $Page++;

	if ($this->Debug)
	{
	  print("Request Parameters:\n");
	  print_r($Params);
	}

	/* Make the request */
	$Result = $this->Proxy->$Func($Params);

	if ($this->Debug)
	{
	  print("Response:\n");
	  print_r($Result);
	}

	/* Handle the return */
	if (($Result != null)              &&
	    IsSet($Result[$TopLevelName])  &&
	    (Count($Result[$TopLevelName]) > 0))
	{
	  $MorePages = true;
	  $Details   = $Result[$TopLevelName];

	  /* Return could be array or scalar; handle both */
	  if (IsSet($Details[0]))
	  {
	    foreach ($Details as $Detail)
	      {
		if (count($Ret) >= $Max)
		{
		  /* Stop when we have enough results */
		  break;
		}

		$Ret[] = $Detail;
	      }
	  }
	  else
	  {
	    $Ret[] = $Details;
	  }

	  /* If we got back less than 10 results, there are no more */
	  if (count($Result[$TopLevelName]) < 10)
	  {
	    $MorePages = false;
	  }
	}
	else
	{
	  //	print("Hmmmm, no result or no details\n");
	  $MorePages = false;
	}
      }
    }
    else
    {
      if ($this->Debug)
      {
	print("Request Parameters:\n");
	print_r($Params);
      }

      /* Make the request */
      $Result = $this->Proxy->$Func($Params);

      if ($this->Debug)
      {
	print("Response:\n");
	print_r($Result);
      }

      /* Handle the return */
      if ($Result != null)
      {
	$Ret = $Result;
      }
      else
      {
	$Ret = null;
      }
    }

    return $Ret;
  }

  /*
   * _EncodeValues -
   *
   *	Encode the HTML special characters in the given
   *	scalar value or each of the array values.
   */

  function _EncodeValues($Values)
  {
    if (is_array($Values))
    {
      for ($i = 0; $i < count($Values); $i++)
      {
	$Values[$i] = htmlentities($Values[$i]);
      }
      return $Values;
    }
    else
    {
      return htmlentities($Values);
    }
  }

  /*
   * DoKeywordSearch -
   *
   *	Perform a search for items with the given keyword, within
   *	the given product category ('books', by default). Return an
   *	array of item details success, null on error.
   */

  function DoKeywordSearch($Keyword, $Type = 'lite', $Category = 'books', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('keyword' => htmlentities($Keyword),
		    'mode'    => htmlentities($Category),
		    'tag'     => $this->AssociateID,
		    'devtag'  => $this->Token,
		    'type'    => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('KeywordSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoBrowseNodeSearch -
   *
   *	Perform a search for items with the given browse node, within
   *	the given product category ('books', by default). Return an
   *	array of item details success, null on error.
   */

  function DoBrowseNodeSearch($BrowseNode, $Type = 'lite', $Category = 'books', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('browse-node' => htmlentities($BrowseNode),
		    'mode'        => htmlentities($Category),
		    'tag'         => $this->AssociateID,
		    'devtag'      => $this->Token,
		    'type'        => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('BrowseNodeSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoAuthorSearch -
   *
   *	Perform a search for items with the given author, within
   *	the given product category ('books', by default). Return an
   *	array of ASINs on success, null on error.
   */

  function DoAuthorSearch($Author, $Type = 'lite', $Category = 'books', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('author' => htmlentities($Author),
		    'mode'   => htmlentities($Category),
		    'tag'    => $this->AssociateID,
		    'devtag' => $this->Token,
		    'type'   => $Type);


    /* Do the search */
    $Ret = $this->_DoSearch('AuthorSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoASINSearch -
   *
   *	Perform a search for items with the given ASIN or ASINs.
   *	Return an array of item details on success, null on error.
   */

  function DoASINSearch($ASIN, $Type = 'lite')
  {
    /* Encode the ASIN or ASINs */
    $ASIN = $this->_EncodeValues($ASIN);

    /* Handle array of values */
    if (is_array($ASIN))
    {
      $Count = count($ASIN);
      $ASIN = implode(',', $ASIN);
    }
    else
    {
      $Count = 1;
    }

    /* Form the parameters */
    $Params = array('asin'   => $ASIN,
		    'tag'    => $this->AssociateID,
		    'devtag' => $this->Token,
		    'type'   => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('AsinSearchRequest', $Params, $Count, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoUPCSearch -
   *
   *	Perform a search for items with the given UPC within
   *	the given product category ('music', by default).
   *	Return an array of item details on success, null on error.
   *
   *	Note: Version 1 of AWS does not support retrieval of
   *	      more than one UPC at a time.
   */

  function DoUPCSearch($UPC, $Type = 'lite', $Category = 'music')
  {
    /* Encode the UPC */
    $UPC = $this->_EncodeValues($UPC);

    /* Form the parameters */
    $Params = array('mode'   => htmlentities($Category),
		    'upc'    => $UPC,
		    'tag'    => $this->AssociateID,
		    'devtag' => $this->Token,
		    'type'   => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('UpcSearchRequest', $Params, 1, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoManufacturerSearch -
   *
   *	Perform a search for items with the given manufacturer
   *	within the given product category ('books', by default).
   *	Return an array of item details success, null on error.
   */

  function DoManufacturerSearch($Manufacturer, $Type = 'lite', $Category = 'books', $Max = DEFAULT_MAX)
  {
    /* Encode the Manufacturer */
    $Manufacturer = $this->_EncodeValues($Manufacturer);

    /* Form the parameters */
    $Params = array('manufacturer' => htmlentities($Manufacturer),
		    'mode'         => htmlentities($Category),
		    'tag'          => $this->AssociateID,
		    'devtag'       => $this->Token,
		    'type'         => $Type);

    //      $Params['sort'] = '+price';

    /* Do the search */
    $Ret = $this->_DoSearch('ManufacturerSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoActorSearch -
   *
   *	Perform a search for items with the given actor, within
   *	the given product category ('dvd', by default). Return an
   *	array of item details success, null on error.
   */

  function DoActorSearch($Actor, $Type = 'lite', $Category = 'dvd', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('actor'  => htmlentities($Actor),
		    'mode'   => htmlentities($Category),
		    'tag'    => $this->AssociateID,
		    'devtag' => $this->Token,
		    'type'   => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('ActorSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoDirectorSearch -
   *
   *	Perform a search for items with the given director, within
   *	the given product category ('dvd', by default). Return an
   *	array of item details success, null on error.
   */

  function DoDirectorSearch($Director, $Type = 'lite', $Category = 'dvd', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('director' => htmlentities($Director),
		    'mode'     => htmlentities($Category),
		    'tag'      => $this->AssociateID,
		    'devtag'   => $this->Token,
		    'type'     => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('DirectorSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoArtistSearch -
   *
   *	Perform a search for items with the given artist, within
   *	the given product category ('music', by default). Return an
   *	array of item details success, null on error.
   */

  function DoArtistSearch($Artist, $Type = 'lite', $Category = 'music', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('artist'  => htmlentities($Artist),
		    'mode'    => htmlentities($Category),
		    'tag'     => $this->AssociateID,
		    'devtag'  => $this->Token,
		    'type'    => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('ArtistSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoListManiaSearch -
   *
   *	Perform a search for items on the given ListMania! list.	
   *	Return an array of item details success, null on error.
   */

  function DoListManiaSearch($List, $Type = 'lite', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('lm_id'  => htmlentities($List),
		    'tag'    => $this->AssociateID,
		    'devtag' => $this->Token,
		    'type'   => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('ListManiaSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoSimilaritySearch -
   *
   *	Perform a search for items that are similar to the given ASIN,
   *	within the given product category ('books', by default). Return
   *	an array of item details on success, null on error.
   */

  function DoSimilaritySearch($ASIN, $Type = 'lite', $Category = 'books', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('asin'   => htmlentities($ASIN),
		    'mode'   => htmlentities($Category),
		    'tag'    => $this->AssociateID,
		    'devtag' => $this->Token,
		    'type'   => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('SimilaritySearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoPowerSearch -
   *
   *	Perform a power search for items using the given query,
   *	within the given product category ('books', by default).
   *	Return an array of item details success, null on error.
   */

  function DoPowerSearch($Power, $Type = 'lite', $Category = 'books', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('power'  => htmlentities($Power),
		    'mode'   => htmlentities($Category),
		    'tag'    => $this->AssociateID,
		    'devtag' => $this->Token,
		    'type'   => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('PowerSearchRequest', $Params, $Max, 'Details');

    /* Return result */
    return $Ret;
  }

  /*
   * DoSellerSearch -
   *
   *	Perform a search for products sold by the given seller with
   *	the given status ('open' or 'closed'). Return an array of item
   *	details on success, null on error.
   */

  function DoSellerSearch($SellerID, $OfferStatus = 'open', $Type = 'lite',
                          $Category = 'books', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('seller_id'   => htmlentities($SellerID),
		    'mode'        => htmlentities($Category),
		    'tag'         => $this->AssociateID,
		    'devtag'      => $this->Token,
		    'offerstatus' => $OfferStatus,	
		    'type'        => $Type);

    /* Do the search */
    $Ret = $this->_DoSearch('SellerSearchRequest', $Params, $Max, 'SellerSearchDetails');

    /* Return result */
    return $Ret;
  }

  /*
   * DoSellerProfileSearch -
   *
   *	Perform a search for information about the given seller.
   *	Return array of seller details on success, null on error.
   */

  function DoSellerProfileSearch($SellerID, $Type = 'lite', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('seller_id'   => htmlentities($SellerID),
		    'tag'         => $this->AssociateID,
		    'devtag'      => $this->Token);

    /* Do the search */
    $Ret = $this->_DoSearch('SellerProfileSearchRequest', $Params, $Max, 'SellerProfileDetails');

    /* Return result */
    return $Ret;
  }

  /*
   * DoExchangeSearch -
   *
   *	Perform a search for information about the given exchange item.
   *	Return array of product details on success, null on error.
   */

  function DoExchangeSearch($ExchangeID, $Type = 'lite', $Max = DEFAULT_MAX)
  {
    /* Form the parameters */
    $Params = array('exchange_id' => htmlentities($ExchangeID),
		    'tag'         => $this->AssociateID,
		    'devtag'      => $this->Token);

    /* Do the search */
    $Ret = $this->_DoSearch('ExchangeSearchRequest', $Params, $Max, null);

    /* Return result */
    return $Ret;
  }
}
