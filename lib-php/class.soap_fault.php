<!doctype html public "-//W3C//DTD HTML 4.0 Transitional//EN"
"http://www.w3.org/TR/REC-html40/loose.dtd">
<html><head>
<!-- ViewCVS -- http://viewcvs.sourceforge.net/
by Greg Stein -- mailto:gstein@lyra.org
-->
<title>CVS log for nusoap/lib/class.soap_fault.php</title>
</head>
<body text="#000000" bgcolor="#ffffff">
<center>
<iframe SRC="http://ads.osdn.com/?op=iframe&position=1&allpositions=1&site_id=2&section=cvs" width="728" height="90" frameborder="0" border="0" MARGINWIDTH="0" MARGINHEIGHT="0" SCROLLING="no"></iframe>
<!-- image audit code -->
<script LANGUAGE="JAVASCRIPT">
<!--
now = new Date();
tail = now.getTime();
document.write("<IMG SRC='http://images-aud.sourceforge.net/pc.gif?l,");
document.write(tail);
document.write("' WIDTH=1 HEIGHT=1 BORDER=0>");
//-->
</SCRIPT>
<noscript>
<img src="http://images-aud.sourceforge.net/pc.gif?l,81677"
WIDTH=1 HEIGHT=1 BORDER=0>
</noscript>
<!-- end audit code -->
</center>
<table width="100%" border=0 cellspacing=0 cellpadding=0>
<tr>
<td rowspan=2><h1>CVS log for nusoap/lib/class.soap_fault.php</h1></td>
<td align=right><img src="/sourceforge_whitebg.gif" alt="(logo)" border=0
width=136 height=79></td>
</tr>
<tr>
<td align=right><h3><b><a target="_blank"
href="/viewcvs.py/*docroot*/help_log.html">ViewCVS and CVS Help</a></b></h3></td>
</tr>
</table>
<a href="/viewcvs.py/nusoap/lib/#class.soap_fault.php"><img src="/icons/small/back.gif" alt="(back)" border=0
width=16 height=16></a>
<b>Up to <a href="/viewcvs.py/#dirlist">[cvs]</a> / <a href="/viewcvs.py/nusoap/#dirlist">nusoap</a> / <a href="/viewcvs.py/nusoap/lib/#dirlist">lib</a> / class.soap_fault.php</b><p>
<a href="#diff">Request diff between arbitrary revisions</a>

<hr noshade>

Default branch: MAIN
<br>
Bookmark a link to:

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?view=markup"><b>HEAD</b></a>
/
(<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php" target="cvs_checkout"
onclick="window.open('/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php', 'cvs_checkout',
'resizable=1,scrollbars=1');return false"
><b>download</b></a>)


<br>



 



<hr size=1 noshade>


<a name="rev1.8"></a>
<a name="HEAD"></a>


Revision <b>1.8</b> -

<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?rev=1.8"

type="text/plain"
>
(download)</a>, view
<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?content-type=text%2Fplain&rev=1.8">(text)</a>
<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?rev=1.8&view=markup">(markup)</a>

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?annotate=1.8">(annotate)</a>



- <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.8">[select for diffs]</a>



<br>

<i>Fri Aug 29 19:23:50 2003 UTC</i> (6 weeks, 5 days ago) by <i>snichol</i>


<br>CVS Tags:

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?only_with_tag=HEAD"><b>HEAD</b></a>






<br>Changes since <b>1.7: +1 -1 lines</b>






<br>Diff to <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.7&amp;r2=1.8">previous 1.7</a>







<pre>Check in everything with new version/@version.

For @version, start using $Id: class.soap_fault.php,v 1.1 2004/01/08 08:45:28 jukebox Exp $.

The version in nusoap_base has been changed to 0.6.6.
</pre>

<hr size=1 noshade>


<a name="rev1.7"></a>
<a name="V0_6_5"></a>


Revision <b>1.7</b> -

<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?rev=1.7"

type="text/plain"
>
(download)</a>, view
<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?content-type=text%2Fplain&rev=1.7">(text)</a>
<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?rev=1.7&view=markup">(markup)</a>

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?annotate=1.7">(annotate)</a>



- <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.7">[select for diffs]</a>



<br>

<i>Wed Jul 23 06:09:30 2003 UTC</i> (2 months, 3 weeks ago) by <i>dietricha</i>


<br>CVS Tags:

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?only_with_tag=V0_6_5"><b>V0_6_5</b></a>






<br>Changes since <b>1.6: +1 -1 lines</b>






<br>Diff to <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.6&amp;r2=1.7">previous 1.6</a>







<pre>- soap_server: fixed bug causing charset encoding not to be passed to the parser

- soap_fault: added default encoding to the fault serialization

- soap_parser: changed the parser to pre-load the parent's result array when processing scalar values. This increases parsing speed.
</pre>

<hr size=1 noshade>


<a name="rev1.6"></a>


Revision <b>1.6</b> -

<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?rev=1.6"

type="text/plain"
>
(download)</a>, view
<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?content-type=text%2Fplain&rev=1.6">(text)</a>
<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?rev=1.6&view=markup">(markup)</a>

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?annotate=1.6">(annotate)</a>



- <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.6">[select for diffs]</a>



<br>

<i>Tue Jul 22 06:46:28 2003 UTC</i> (2 months, 3 weeks ago) by <i>dietricha</i>






<br>Changes since <b>1.5: +1 -1 lines</b>






<br>Diff to <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.5&amp;r2=1.6">previous 1.5</a>







<pre>- added a changelog
- upped the version number to 0.6.5
- soap_transport_http: SOAPAction header is quoted again, fixes problem w/ Weblogic Server
- applied Jason Levitt patch for proper array serialization, fixes problem w/ Amazon shopping cart services
- fixed null value serialization
- applied patch from "BZC ToOn'S" - fixes wsdl serialization when no parameters
- applied John's patch, implementing compression for the server
</pre>

<hr size=1 noshade>


<a name="rev1.5"></a>


Revision <b>1.5</b> -

<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?rev=1.5"

type="text/plain"
>
(download)</a>, view
<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?content-type=text%2Fplain&rev=1.5">(text)</a>
<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?rev=1.5&view=markup">(markup)</a>

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?annotate=1.5">(annotate)</a>



- <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.5">[select for diffs]</a>



<br>

<i>Mon May  5 06:09:55 2003 UTC</i> (5 months, 1 week ago) by <i>dietricha</i>






<br>Changes since <b>1.4: +1 -1 lines</b>






<br>Diff to <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.4&amp;r2=1.5">previous 1.4</a>







<pre>fixed a bug in wsdl class: wrong type parameter to serializeType()
fixed truncation of leading zeroes in params typed as strings
added steven brown's patch for adding wsdl documention in nusoap servers
updated version numbers (somehow didn't make it into the 0.6.4 commit)
built new nusoap.php
</pre>

<hr size=1 noshade>


<a name="rev1.4"></a>


Revision <b>1.4</b> -

<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?rev=1.4"

type="text/plain"
>
(download)</a>, view
<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?content-type=text%2Fplain&rev=1.4">(text)</a>
<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?rev=1.4&view=markup">(markup)</a>

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?annotate=1.4">(annotate)</a>



- <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.4">[select for diffs]</a>



<br>

<i>Sat Dec  7 23:19:48 2002 UTC</i> (10 months, 1 week ago) by <i>dietricha</i>






<br>Changes since <b>1.3: +4 -0 lines</b>






<br>Diff to <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.3&amp;r2=1.4">previous 1.3</a>







<pre>more doc/lit patches
an array serialization fix
</pre>

<hr size=1 noshade>


<a name="rev1.3"></a>


Revision <b>1.3</b> -

<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?rev=1.3"

type="text/plain"
>
(download)</a>, view
<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?content-type=text%2Fplain&rev=1.3">(text)</a>
<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?rev=1.3&view=markup">(markup)</a>

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?annotate=1.3">(annotate)</a>



- <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.3">[select for diffs]</a>



<br>

<i>Sat Oct 26 01:00:52 2002 UTC</i> (11 months, 2 weeks ago) by <i>dietricha</i>






<br>Changes since <b>1.2: +1 -0 lines</b>






<br>Diff to <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.2&amp;r2=1.3">previous 1.2</a>







<pre>more clear fixes.
</pre>

<hr size=1 noshade>


<a name="rev1.2"></a>


Revision <b>1.2</b> -

<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?rev=1.2"

type="text/plain"
>
(download)</a>, view
<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?content-type=text%2Fplain&rev=1.2">(text)</a>
<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?rev=1.2&view=markup">(markup)</a>

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?annotate=1.2">(annotate)</a>



- <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.2">[select for diffs]</a>



<br>

<i>Fri Oct 25 07:16:11 2002 UTC</i> (11 months, 3 weeks ago) by <i>dietricha</i>






<br>Changes since <b>1.1: +2 -0 lines</b>






<br>Diff to <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.1&amp;r2=1.2">previous 1.1</a>







<pre>built new nusoap.php
updated version numbers to 0.6.3
</pre>

<hr size=1 noshade>


<a name="rev1.1"></a>


Revision <b>1.1</b> -

<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?rev=1.1"

type="text/plain"
>
(download)</a>, view
<a href="/viewcvs.py/*checkout*/nusoap/lib/class.soap_fault.php?content-type=text%2Fplain&rev=1.1">(text)</a>
<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?rev=1.1&view=markup">(markup)</a>

<a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?annotate=1.1">(annotate)</a>



- <a href="/viewcvs.py/nusoap/lib/class.soap_fault.php?r1=1.1">[select for diffs]</a>



<br>

<i>Fri Jul 12 05:08:56 2002 UTC</i> (15 months ago) by <i>dietricha</i>











<pre>initial commits
</pre>

 


<a name=diff></a>
<hr noshade>
This form allows you to request diffs between any two revisions of
a file. You may select a symbolic revision name using the selection
box or you may type in a numeric name using the type-in text box.
<p>
<form method=get action="/viewcvs.py/nusoap/lib/class.soap_fault.php" name=diff_select>

Diffs between
<select name="r1">
<option value="text" selected>Use Text Field</option>

<option value="1.7:V0_6_5">V0_6_5</option>

<option value="1.8:MAIN">MAIN</option>

<option value="1.8:HEAD">HEAD</option>

</select>
<input type="TEXT" size="12" name="tr1" value="1.1"
onChange="document.diff_select.r1.selectedIndex=0">
and
<select name="r2">
<option value="text" selected>Use Text Field</option>

<option value="1.7:V0_6_5">V0_6_5</option>

<option value="1.8:MAIN">MAIN</option>

<option value="1.8:HEAD">HEAD</option>

</select>
<input type="TEXT" size="12" name="tr2" value="1.8"
onChange="document.diff_select.r1.selectedIndex=0">
<br>Type of Diff should be a
<select name="diff_format" onchange="submit()">
<option value="h" selected>Colored Diff</option>
<option value="l" >Long Colored Diff</option>
<option value="u" >Unidiff</option>
<option value="c" >Context Diff</option>
<option value="s" >Side by Side</option>
</select>
<input type=submit value=" Get Diffs "></form>


<hr noshade>
<a name=branch></a>
<form method=GET action="/viewcvs.py/nusoap/lib/class.soap_fault.php">

View only Branch:
<select name="only_with_tag" onchange="submit()">
<option value="" selected>Show all branches</option>

<option value="MAIN" >MAIN</option>

</select>
<input type=submit value=" View Branch ">
</form>


<hr noshade>
<a name=logsort></a>
<form method=get action="/viewcvs.py/nusoap/lib/class.soap_fault.php">

Sort log by:
<select name="logsort" onchange="submit()">
<option value="cvs" >Not sorted</option>
<option value="date" selected>Commit date</option>
<option value="rev" >Revision</option>
</select>
<input type=submit value=" Sort ">
</form>


<hr noshade>
<table width="100%" border=0 cellpadding=0 cellspacing=0><tr>
<td align=left><address><a href="http://sourceforge.net/">Back to SourceForge.net</a></address></td>
<td align=right>
Powered by<br><a href="http://viewcvs.sourceforge.net/">ViewCVS</a>
</td></tr></table>
</body></html>

