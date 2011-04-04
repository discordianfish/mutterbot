#!/usr/bin/env perl
use strict;
use warnings;
use Net::Twitter;
use feature 'say';
use File::HomeDir;
use Config::Simple;
use Data::Dumper;
use List::Util 'first';
# please use another KEY+SECRET for your fork
use constant C_KEY => 'cv5PWaCvTcirEihc1gvYA';
use constant C_SECRET => 'fkwRkjFvstVIwIzajksc2HtownmSKN2T1IDIqkYZk';
use constant WHAT => 'deine mutter OR deine mudda';
use constant FILTER => qr/mutterbot|(^|\W)RT @/;    # ingore tweets to avoid RT
                                                    # pingpong;


my %LAST;

my $t = Net::Twitter->new(
    traits => [ qw( API::REST RetryOnError OAuth RetryOnError API::Search ) ],
    # we are a bot, our life is meaningless without response. so try desperately:
    max_retries => 0,
    consumer_key => C_KEY,
    consumer_secret => C_SECRET,
);

my $config = Config::Simple->new(syntax => 'ini');
my $config_file = $ENV{CONFIG} || File::HomeDir->my_home . '/.mutterbot.conf';

if (-e $config_file)
{
    $config->read($config_file);

    $t->access_token($config->param('token'));
    $t->access_token_secret($config->param('secret'));
}

unless ($t->authorized) {
    say "authorize app at ", $t->get_authorization_url, " and enter PIN:";
    my $verifier = <STDIN>;
    chomp $verifier;

    my ($token, $secret, $uid, $name) = $t->request_access_token(verifier => $verifier);
    $config->param(token => $token);
    $config->param(secret => $secret);
    $config->write($config_file);
}

my @rt;
while (1)
{
    my $tweets = eval { $t->search(WHAT)->{results} }
        or sleep 60 and next;

    for my $tweet (@$tweets)
    {
        my $id = $tweet->{id};
        next if first { $_ eq $id } @rt;
        next if $tweet->{text} =~ FILTER; # filter tweets
        say 'RT @' . $tweet->{from_user} . ': ' .  $tweet->{text};

        do
        {
            eval { $t->retweet($id) };
            if ($@)
            {
                if ($@ =~ /^403 Forbidden/)
                {
                    warn 'already retweeted, skipping';
                } else {
                    warn "failed, retrying in 30secs: '$@'";
                    sleep 30;
                }
            } else { last } # sorry, I'm drunk
        };
        undef $@;
        say 'done';
        push @rt, $id;
    }
    sleep 60;
}
