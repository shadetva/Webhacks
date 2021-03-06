#module-starter --module=webHacks --author="Daniel Torres" --email=daniel.torres@owasp.org
# May 27 2017
# web Hacks
package webHacks;
our $VERSION = '1.0';
use Moose;
use Text::Table;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Cookies;
use URI::Escape;
use HTTP::Request;
use HTTP::Response;
use Net::SSL (); # From Crypt-SSLeay
no warnings 'uninitialized';

$Net::HTTPS::SSL_SOCKET_CLASS = "Net::SSL"; # Force use of Net::SSL for proxy compatibility

{
has 'rhost', is => 'rw', isa => 'Str',default => '';	
has 'rport', is => 'rw', isa => 'Str',default => '80';	
has 'path', is => 'rw', isa => 'Str',default => '/';	
has 'ssl', is => 'rw', isa => 'Int',default => 0;	

has user_agent      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_host      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_port      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_user      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_pass      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_env      => ( isa => 'Str', is => 'rw', default => '' );
has debug      => ( isa => 'Int', is => 'rw', default => 0 );
has headers  => ( isa => 'Object', is => 'rw', lazy => 1, builder => '_build_headers' );
has browser  => ( isa => 'Object', is => 'rw', lazy => 1, builder => '_build_browser' );

########### scan directories #######       
sub dirbuster
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $path = $self->path;
my $ssl = $self->ssl;
my ($url_file) = @_;

print "ssl in dirbuster $ssl \n" if ($debug);

my $lines = `wc -l $url_file | cut -d " " -f1`;
$lines =~ s/\n//g;
my $time = int($lines/600);

print "######### Usando archivo: $url_file ##################### \n\n";
print "Tiempo estimado en probar $lines URLs : $time minutos\n\n";

my $result_table = Text::Table->new(
        "URL", "  STATUS", "RISKY METHODS"
);
    
my $i=0;
open (MYINPUT,"<$url_file") || die "ERROR: Can not open the file $url_file\n";
while (my $file=<MYINPUT>)
{ 
$file =~ s/\n//g; 	

if (! ($file =~ /\./m)){	 
	$file = $file."/";
 }

my $url;
if ($ssl)
  {$url = "https://".$rhost.":".$rport.$path.$file;}
else
  {$url = "http://".$rhost.":".$rport.$path.$file;}
  
#Adicionar backslash
 if(!($file =~ /\./m)){
	$file=$file."/"; 
 } 
 
#my $url;
# We add httpS if is a SSL service en the GET,POST,etc function
#$url = "http://".$rhost.":".$rport.$path.$file;

my $response = $self->dispatch(url => $url,method => 'GET',headers => $headers);
my $status = $response->status_line;
if($status !~ /404|500/m){	
	my $response2 = $self->dispatch(url => $url,method => 'OPTIONS',headers => $headers);
	my $options = " ";
	$options = $response2->{_headers}->{allow};	
	$options =~ s/GET|HEAD|POST|OPTIONS//g; # delete safe methods	
	$options =~ s/,,//g; # delete safe methods	
    $result_table->add($url,$status,$options);	
}

}
close MYINPUT;
print $result_table;

}


#search for directories like   192.168.0.1/~username
sub userbuster
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $path = $self->path;
my $ssl = $self->ssl;

my ($url_file) = @_;
my $lines = `wc -l $url_file | cut -d " " -f1`;
$lines =~ s/\n//g;
my $time = int($lines/600);
print "######### Usando archivo: $url_file ##################### \n\n";
print "Tiempo estimado en probar $lines URLs : $time minutos\n\n";

my $result_table = Text::Table->new(
        "URL", "  STATUS"
);
    

open (MYINPUT,"<$url_file") || die "ERROR: Can not open the file $url_file\n";
while (my $file=<MYINPUT>)
{ 
$file =~ s/\n//g; 	


my $url;
if ($ssl)
  {$url = "https://".$rhost.":".$rport.$path."~".$file;}
else
  {$url = "http://".$rhost.":".$rport.$path."~".$file;}

my $response = $self->dispatch(url => $url,method => 'GET',headers => $headers);
my $status = $response->status_line;
if($status !~ /404/m){	
    $result_table->add($url,$status);	
}

}
close MYINPUT;
print $result_table;

}



#search for backupfiles
sub backupbuster
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $path = $self->path;
my $ssl = $self->ssl;

my ($url_file) = @_;

my $lines = `wc -l $url_file | cut -d " " -f1`;
$lines =~ s/\n//g;
my $time = int($lines/600);

print "######### Usando archivo: $url_file ##################### \n\n";
print "Tiempo estimado en probar $lines URLs : $time minutos\n\n";


my $result_table = Text::Table->new(
        "URL", "  STATUS"
);
    

open (MYINPUT,"<$url_file") || die "ERROR: Can not open the file $url_file\n";
while (my $file=<MYINPUT>)
{
	my @backups = ("FILE","FILE.bak","FILE-bak", "FILE~", "FILE.save", "FILE.swp", "FILE.old","Copy of FILE","FILE (copia 1)",".FILE.swp");
	$file =~ s/\n//g; 	
	#print "file $file \n";
	my $url;

	foreach my $backup_file (@backups) {			
		$backup_file =~ s/FILE/$file/g;    		
		
		if ($ssl)
			{$url = "https://".$rhost.":".$rport.$path.$backup_file;}
		else
			{$url = "http://".$rhost.":".$rport.$path.$backup_file;}
				    

		my $response = $self->dispatch(url => $url,method => 'GET',headers => $headers);
		my $status = $response->status_line;
		if($status !~ /404/m){			
			$result_table->add($url,$status);	
		}   
  
	}# end foreach
} # end while
close MYINPUT;
print $result_table;

}



sub defaultPassword
{
my $self = shift;
my $headers = $self->headers;
my $debug = $self->debug;
my $rhost = $self->rhost;
my $rport = $self->rport;
my $ssl = $self->ssl;

my ($software) = @_;

print "######### Testendo: $software ##################### \n\n" if($debug);

my $url;
if ($ssl)
  {$url = "https://".$rhost.":".$rport;}
else
  {$url = "http://".$rhost.":".$rport;}

if ($software eq "ZKSoftware")
{

	my $hash_data = {'username' => 'administrator', 
				'userpwd' => '123456'
				};	
	
	my $post_data = convert_hash($hash_data);
		
	my $response = $self->dispatch(url => $url."/csl/check",method => 'POST',post_data =>$post_data, headers => $headers);
	my $decoded_response = $response->decoded_content;
	if($decoded_response =~ /Error/m)
	{	
		print "No default password \n" if ($debug);
	}
	else
	{	
		print "ZKSoftware: Default password (administrator:123456)\n";
	}

}#ZKSoftware
}



################################### build objects ########################

################### build headers object #####################
sub _build_headers {   
#print "building header \n";
my $self = shift;
my $debug = $self->debug;
my $headers = HTTP::Headers->new;


my @user_agents=("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/28.0.1500.71 Chrome/28.0.1500.71 Safari/537.36",
			  "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.62 Safari/537.36",
			  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:23.0) Gecko/20100101 Firefox/23.0",
			  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.63 Safari/537.31",
			  "Mozilla/5.0 (Windows NT 6.2; WOW64; rv:22.0) Gecko/20100101 Firefox/22.0",
			  "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.62 Safari/537.36",
			  "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)",
			  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.95 Safari/537.36");			   
			  
my $user_agent = @user_agents[rand($#user_agents+1)];    
print "user_agent $user_agent \n" if ($debug);

$headers->header('User-Agent' => $user_agent); 
$headers->header('Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'); 
$headers->header('Connection' => 'keep-alive'); 
$headers->header('Accept-Encoding' => [ HTTP::Message::decodable() ]);

return $headers; 
}


###################################### internal functions ###################

#Convert a hash in a string format used to send POST request
sub convert_hash
{
my ($hash_data)=@_;
my $post_data ='';
foreach my $key (keys %{ $hash_data }) {    
    my $value = $hash_data->{$key};
    $post_data = $post_data.uri_escape($key)."=".$value."&";    
}	
chop($post_data); # delete last character (&)
 #$post_data = uri_escape($post_data);
return $post_data;
}


sub dispatch {    
my $self = shift;
my $debug = $self->debug;
my %options = @_;

my $url = $options{ url };
my $method = $options{ method };
my $headers = $options{ headers };
my $response;

if ($method eq 'POST_OLD')
  {     
   my $post_data = $options{ post_data };        
   $response = $self->browser->post($url,$post_data);
  }  
    
if ($method eq 'GET')
  { my $req = HTTP::Request->new(GET => $url, $headers);
    $response = $self->browser->request($req)
  }

if ($method eq 'OPTIONS')
  { my $req = HTTP::Request->new(OPTIONS => $url, $headers);
    $response = $self->browser->request($req)
  }  
  
if ($method eq 'POST')
  {     
   my $post_data = $options{ post_data };           
   my $req = HTTP::Request->new(POST => $url, $headers);
   $req->content($post_data);
   $response = $self->browser->request($req);    
  }  
  
if ($method eq 'POST_MULTIPART')
  {    	   
   my $post_data = $options{ post_data }; 
   $headers->header('Content_Type' => 'multipart/form-data');
    my $req = HTTP::Request->new(POST => $url, $headers);
   $req->content($post_data);
   #$response = $self->browser->post($url,Content_Type => 'multipart/form-data', Content => $post_data, $headers);
   $response = $self->browser->request($req);    
  } 

if ($method eq 'POST_FILE')
  { 
	my $post_data = $options{ post_data };         	    
	$headers->header('Content_Type' => 'application/atom+xml');
    my $req = HTTP::Request->new(POST => $url, $headers);
    $req->content($post_data);
    #$response = $self->browser->post( $url, Content_Type => 'application/atom+xml', Content => $post_data, $headers);                 
    $response = $self->browser->request($req);    
  }  
      
  
return $response;
}

################### build browser object #####################	
sub _build_browser {    

my $self = shift;
my $rhost = $self->rhost;
my $rport = $self->rport;

my $debug = $self->debug;
my $proxy_host = $self->proxy_host;
my $proxy_port = $self->proxy_port;
my $proxy_user = $self->proxy_user;
my $proxy_pass = $self->proxy_pass;
my $proxy_env = $self->proxy_env;
print "building browser \n" if ($debug);


my $browser = LWP::UserAgent->new;

$browser->timeout(10);
$browser->cookie_jar(HTTP::Cookies->new());
$browser->show_progress(1) if ($debug);

my $ssl_output = `get_ssl_cert.py $rhost $rport 2>/dev/null`;
if($ssl_output =~ /CN/m)
	{$self->ssl(1);print "SSL detected \n" if ($debug);}
else
	{$self->ssl(0); print "NO SSL detected \n" if ($debug);}

print "proxy_env $proxy_env \n" if ($debug);

if ( $proxy_env eq 'ENV' )
{
print "set ENV PROXY \n";
$Net::HTTPS::SSL_SOCKET_CLASS = "Net::SSL"; # Force use of Net::SSL
$ENV{HTTPS_PROXY} = "http://".$proxy_host.":".$proxy_port;

}
elsif (($proxy_user ne "") && ($proxy_host ne ""))
{
 $browser->proxy(['http', 'https'], 'http://'.$proxy_user.':'.$proxy_pass.'@'.$proxy_host.':'.$proxy_port); # Using a private proxy
}
elsif ($proxy_host ne "")
   { $browser->proxy(['http', 'https'], 'http://'.$proxy_host.':'.$proxy_port);} # Using a public proxy
 else
   { 
      $browser->env_proxy;} # No proxy       

return $browser;     
}
    
}
1;
