package WWW::API::Trello;
use warnings;
use strict;
use Mojo::Base -base;
use Data::Dumper qw/Dumper/;
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::JSON;

=head1 NAME

WWW::API::Trello - Perl API wrapper around the Trello API

=head1 DESCRIPTION

 This is a tiny wrapper around the Trello API.
 Give it a key and a token and it'll let you call any Trello API method.
 You just need to call the get, post, put, delete method of this API
 with a valid path, and url query args in a hash, and it'll make the call 
 and return a Perl data structure.

 See https://trello.com/docs/api/index.html for valid methods.

 A few methods are tested in t/www-api-trello.t.  
 Testing all of the Trello methods you're interested in using is left as an excercise for the reader.

=head1 USAGE

 my $t = WWW::API::Trello->new({ key => 'YOURDEVKEY', token => 'YOURTOKEN', name_keys => 1 });

 Get a list of cards

 my $cards = $t->get({ path  => "lists/$list_id/cards" });

=cut

=head1 OPTIONS

There are several ways to pass in options.
You can call new() with a reference to a hash of options (these take priority).  This is the preferred method.
You can specify options in environment variables (these are superseded by values passed in).  
This can be a good option to pass in your key and token.
Or, you can not pass anything and go with the default if the default works for you.

=over 4

=cut

# Create accessors using mojo-ness

=item key - Your Trello API key (required)
=cut
has 'key'         => sub { shift->_default({ var => 'key', required => 1 }); };

=item token - Your Trello API token  (required for write operations or to work with private boards)
=cut
has 'token'       => sub { shift->_default({ var => 'token', required => 1 }); };

=item base - The base of the Trello API url (default https://api.trello.com)
=cut
has 'base'        => sub { shift->_default({ var => 'base', default => "https://api.trello.com" }) };

=item api_version - The Trello API version to use (default 1)
=cut
has 'api_version' => sub { shift->_default({ var => 'api_version', default => '1' }); };

=item debug - print debugging information  (default 0)
=cut
has 'debug'       => sub { shift->_default({ var => 'debug', default => 0 }); };

=item sleep_time - Time to sleep between requests to the Trello API (default 1 second)
 Be kind, and don't hammer their API too hard ;)
=cut
has 'sleep_time'  => sub { shift->_default({ var => 'sleep_time', default => 1}); };

=item name_keys (default 0)
 In cases where an array of items is returned, and each item has a name, the data structure returned
 can be tweaked so that it's a hash where the key of the hash is the name of the item.
 Be careful as this may cause issues if items have the same name.
=cut
has 'name_keys'   => sub { shift->_default({ var => 'name_keys', default => 0 }); };

=item base_href - The http://.../1/ part of the API URL (default built based on the base and api_version)
 Be kind, and don't hammer their API too hard ;)
=cut
has 'base_href'   => sub { $_[0]->_default({ var => 'base_href', default => $_[0]->base."/".$_[0]->api_version, required => 1 }); };

sub _default {
	my ($self,$args) = @_;
	# Get value passed in, or value from $ENV, or default
	my $var       = $args->{var} or die "need a var";
	my $default   = $args->{default};
	my $env_var   = uc("TRELLO_".$var);
	my $ret       = defined $self->{$var}  ? $self->{$var}  : 
					defined $ENV{$env_var} ? $ENV{$env_var} : $default;
	if (not defined $ret and $args->{required}) {
		die "Field $var is required!";
	}
	return $ret;
}

=head1 METHODS

 The methods here are wrappers around making GET/POST/PUT/DELETE requests to the Trello API.
 You can call any method by passing an arbitrary path parameter and query infos.

 For the full API reference, see
 https://trello.com/docs/api/index.html
 If you want to actually do anything with this module you'll need to reference that ;)

=cut

sub ua {
	return shift->{_ua} ||= do { Mojo::UserAgent->new(); };
}

=over 4

=item get

Call any GET method on the Trello API.

Example paths:

 boards/$board_id/lists
 lists/$list_id/cards
 organizations/$organization/boards

Examples:

    my $cards = $t->get({ path  => "lists/$list_id/cards" });

    $t->get({ 
		path  => "lists/$list_id/cards",
		query => {
			foo => 1,
			goo => 2,
		},
	});

=back

=cut

sub get {
	my ($self,$args) = @_;
	return $self->_call({ method => 'get', args => $args });
}

=over 4

=item post

Call any POST method on the Trello API.

Example paths:
 cards
 lists/$list_id/archiveAllCards

Examples:

	my $new_card = $t->post({ 
		path  => 'cards',
		query => {
			name   => $card_title,
			idList => $list_id,
			desc   => $card_description,
		},
	});

	my $result = $t->post({ path => "lists/$list_id/archiveAllCards" });

=back

=cut

sub post {
	my ($self,$args) = @_;
	return $self->_call({ method => 'post', args => $args });
}

=over 4

=item put

Call any PUT method on the Trello API.

Examples:

...

=back

=cut

sub put {
	my ($self,$args) = @_;
	return $self->_call({ method => 'put', args => $args });

}

=over 4

=item delete

Call any DELETE method on the Trello API.

Examples:

...

=back

=cut

sub delete {
	my ($self,$args) = @_;
	return $self->_call({ method => 'delete', args => $args });
}

sub _call {
	# Internal method to make and handle the call to the Trello API
	# pass in method, path, query(opt), ct_args(opt)
	my ($self,$args) = @_;
	my $method  = delete $args->{method} || '';
	die "need a method like GET PUT POST DELETE"
		unless $method =~ /^get|put|post|delete$/i;
	$method     = lc($method);
	my $ct_args = delete $args->{ct_args}; # reserved for args specific to this method
	$args = delete $args->{args};

	my $url   = $self->_makeUrl($args);
	my $t_ret = $self->ua->$method($url);
	sleep $self->sleep_time; # pause to avoid rate limiting
	if (not $t_ret->success) {
		my ($err, $code) = $t_ret->error;
		die "[$code] Error getting url '$url': $err\n";
	}
	if ( !$t_ret->res or $t_ret->res->error ) {
		die "Error getting url '$url': $t_ret->res->error)\n";
	}

	my $data;
	eval { 
		$data = $t_ret->res->json;
	};
	if (my $e = $@) {
		die "Error parsing JSON from returned text from url '$url': $e";
	}
	die Dumper($t_ret)."\nNo json returned form url $url?\n" if not defined $data;

	if (ref($data) eq 'ARRAY' and @$data > 0 and $self->name_keys and defined $data->[0]{name}) {
		# handle case where returned info is list or not ...
		my $list_ = {};
		foreach my $item ( @$data ) {
			$self->_debug("item name: $item->{name}");
			$list_->{$item->{name}} = $item;
		}
		return $list_;
	}
	if (ref($data) eq 'ARRAY' and @$data == 0) {
		return undef;
	}
	return $data;
}

sub _makeUrl {
	my ($self,$args) = @_;
	$args->{path}  or  die "need path ".Dumper($args);
	$args->{query} ||= {};
	$args->{query}{key}   ||= $self->key;
	$args->{query}{token} ||= $self->token;
	my $full              ||= $self->base_href;
	$full   .= "/".$args->{path} if $args->{path};
	my $url  = Mojo::URL->new($full);
	$url->query($args->{query}) if $args->{query};
	$self->_debug("url is: $url");
	return $url;
}

sub _debug {
	my ($self,$message,$args) = @_;
	$|++ if not $|; # autoflush on
	if ($self->debug) {
		print STDERR "$message\n";
	}
}

'THE TRUTH IS OUT THERE';

=head1 AUTHOR

Bryan Gmyrek <bdg@hushmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Bryan Gmyrek

This is free software; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language system itself.