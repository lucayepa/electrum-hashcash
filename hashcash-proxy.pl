#!/usr/bin/perl

use warnings;
use strict;
use JSON;
use Digest::SHA qw(sha256_hex);
use Getopt::Long;
use String::Random qw(random_regex);

use IO::Socket;
use IO::Select;

my $json = JSON->new->canonical;

my $usage = "Usage: $0 --listen_port=1080 --target_host=localhost --target_port=50001";
my $listen_port=0;
my $target_host="";
my $target_port=0;
GetOptions (
            "listen_port=i" => \$listen_port,
            "target_port=i" => \$target_port,
            "target_host=s" => \$target_host,
           )
    or die $usage;

$listen_port and $target_port and ($target_host ne "")
    or die $usage;

my $serverside = ($0 =~ /server/);

my @allowed_ips = ('1.2.3.4', '5.6.7.8', '127.0.0.1', '192.168.1.2');
my $ioset = IO::Select->new;
my %socket_map;

my $debug = 1;

sub new_conn {
    my ($host, $port) = @_;
    return IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port
    ) || die "Unable to connect to $host:$port: $!";
}

sub new_server {
    my ($host, $port) = @_;
    my $server = IO::Socket::INET->new(
        LocalAddr => $host,
        LocalPort => $port,
        ReuseAddr => 1,
        Listen    => 100
    ) || die "Unable to listen on $host:$port: $!";
}

sub new_connection {
    my $server = shift;
    my $client = $server->accept;
    my $client_ip = client_ip($client);

    unless (client_allowed($client)) {
        print "Connection from $client_ip denied.\n" if $debug;
        $client->close;
        return;
    }
    print "Connection from $client_ip accepted.\n" if $debug;

    my $remote = new_conn($target_host, $target_port);
    $ioset->add($client);
    $ioset->add($remote);

    $socket_map{$client} = $remote;
    $socket_map{$remote} = $client;
}

sub close_connection {
    my $client = shift;
    my $client_ip = client_ip($client);
    my $remote = $socket_map{$client};
    
    $ioset->remove($client);
    $ioset->remove($remote);

    delete $socket_map{$client};
    delete $socket_map{$remote};

    $client->close;
    $remote->close;

    print "Connection from $client_ip closed.\n" if $debug;
}

sub client_ip {
    my $client = shift;
    return inet_ntoa($client->sockaddr);
}

sub client_allowed {
    my $client = shift;
    my $client_ip = client_ip($client);
    return grep { $_ eq $client_ip } @allowed_ips;
}

sub check_pow {
    my $h = shift;
    not exists $h->{'pow'} and return 0;
    my $pow = $h->{'pow'};
    delete $h->{'pow'};
    my $sha256 = sha256_hex($json->encode($h));
    ($pow ne $sha256) and return 0;
    delete $h->{'nonce'};
    $sha256 =~ /^0000/ and return 1;
    return 0;
}

sub set_pow {
    my $h = shift;
    my $nonce = "";
    my $sha256 = "zz";
    while ($sha256 !~ /^0000/) {
        $nonce = random_regex('[A-Za-z0-9]' x 10);
        $h->{'nonce'} = $nonce;
        $sha256 = sha256_hex($json->encode($h));
    }
    $h->{pow} = $sha256;
    return $json->encode($h);
}

print "Starting a server on 0.0.0.0:$listen_port\n";
my $server = new_server('0.0.0.0', $listen_port);
$ioset->add($server);

while (1) {
    for my $socket ($ioset->can_read) {
        if ($socket == $server) {
            new_connection($server);
        }
        else {
            next unless exists $socket_map{$socket};
            my $remote = $socket_map{$socket};
            my $buffer;
            my $read = $socket->sysread($buffer, 4096);
            if ($read) {
                my $h = $json->decode($buffer);
                if (exists $h->{'method'}) {
                    #request from client
                    if ($serverside) {
                        #we are on the server
                        if(check_pow($h)) {
                            #pow ok => send to server
                            $remote->syswrite($buffer);
                        } else {
                            #pow not ok => do nothing
                        }
                    } else {
                        #We are on the client side
                        my $new_buffer = set_pow($h);
                        $remote->syswrite($new_buffer."\n");
                    }
                } else {
                    #answer from server to client => no pow
                    $remote->syswrite($buffer);
                }
            }
            else {
                close_connection($socket);
            }
        }
    }
}
