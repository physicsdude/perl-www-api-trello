use Test::More tests => 23;
use Test::Exception;
use Data::Dumper qw/Dumper/;
use FindBin qw/$Bin/;
use lib "$Bin/../";
BEGIN { 
	use_ok( 'WWW::API::Trello' );
}

# Tests, they're in here.

# Usage example:
# TRELLO_KEY='yourtrellokey' TRELLO_TOKEN='youtrellotoken' prove -v ./www-api-trello.t

# ThroatWobblerMangrove https://www.youtube.com/watch?v=ehKGlT2EW1Q

my $trello_api_version = 1;

my %o = (
	app_name      => $ENV{TRELLO_APP_NAME}     || "TestFailBot",
	key           => $ENV{TRELLO_KEY},
	token         => $ENV{TRELLO_TOKEN},
	board         => $ENV{TRELLO_BOARD_TEST}   || "ThroatWobblerMangrovePartDeux",
	organization  => $ENV{TRELLO_ORGANIZATION} || 'lwrandd',
	default_list  => $ENV{TRELLO_LIST}         || 'TestFailBot Cards',
	card_limit    => $ENV{TRELLO_CARD_LIMIT}   || 50,
	debug         => defined $ENV{TRELLO_DEBUG}         ? $ENV{TRELLO_DEBUG}         : 0,
	name_keys     => defined $ENV{TRELLO_NAME_KEYS}     ? $ENV{TRELLO_NAME_KEYS}     : 1,
	api_version   => defined $ENV{TRELLO_API_VERSION}   ? $ENV{TRELLO_API_VERSION}   : 1,
	sleep_time    => defined $ENV{TRELLO_SLEEP_TIME}    ? $ENV{TRELLO_SLEEP_TIME}    : 2,
);

run_tests();

sub run_tests {
	my $t;
	if (!$o{key})   { diag("No key set, skipping.  Set one in enviornment variable TRELLO_KEY");   return; } 
	if (!$o{token}) { diag("No token set, skipping.  Set one in environment variable TRELLO_TOKEN"); return; } 

	lives_ok(sub { $t = WWW::API::Trello->new({%o}); }, "Can create new WWW::API::Trello object instance.") or return;
	ok($t,"object instance exists");
	is($t->{board},$o{board},"Correct board is set");

	my ($boards,$board,$board_id);
	lives_ok(sub { $boards = $t->get({ path => "organizations/$o{organization}/boards" }) }, "Can get list of boards") or return;
	is(ref($boards),'HASH',"Got a hash of boards") or return;
	my $board    = $boards->{$o{board}};
	ok($board,"Got a board named $o{board}") or return;
	my $board_id = $boards->{$o{board}}{id};
	ok($board_id,"Board has an id ($board_id)");

	my ($lists,$list,$list_id);
	lives_ok(sub { $lists = $t->get({ path => "boards/$board_id/lists" }) }, "Can get all lists on board $board_id") or return;
	is(ref($lists),'HASH',"Got a hash of lists") or return;
	my $list    = $lists->{$o{default_list}};
	ok($list,"Got a list named $o{default_list}") or return;
	my $list_id = $lists->{$o{default_list}}{id};
	ok($list_id,"list has an id ($list_id)");

	if ($o{board} !~ /throatwobblermangrove/i and not $ENV{I_RULE_U} == 1) {
		diag("Refusing to run write mode tests on this board - add ThroatWobblerMangrove to the board name to enable.");
		return;
	}

	my ($card,$card_args);
	$card_args = {
		name    => "Raymond",
		idList  => $list_id,
		desc    => "This is just silly!",
	};
	lives_ok(sub { $card = $t->post({ path => "cards", query => $card_args }) },
		"Can create a card called $card_args->{name}") or return;

	$card_args = {
		name    => "Luxury",
		idList  => $list_id,
		desc    => "This is just ... really silly!",
	};
	lives_ok(sub { $card = $t->post({ path => "cards", query => $card_args }) },
		"Can create a card called $card_args->{name}") or return;

	$card_args = {
		name    => "Yacht",
		idList  => $list_id,
		desc    => "This is just ... really ... really silly!",
	};
	lives_ok(sub { $card = $t->post({ path => "cards", query => $card_args }) },
		"Can create a card called $card_args->{name}") or return;

	my ($cards);
	lives_ok(sub { $cards = $t->get({ path => "lists/$list_id/cards" }) },
		"Can get list of cards for list $list_id");
	is(ref($cards),"HASH","Cards is a hash");
	foreach my $name (qw/Raymond Luxury Yacht/) {
		ok($cards->{$name},"Got card for $name");
	}

	my ($checklist);
	$check_args = {
		name    => "Precious things",
		idCard  => $card->{id},
	};
	lives_ok(sub { $checklist = $t->post({ path => "checklists", query => $check_args }) },
		"Can create a checklist called $check_args->{name} on card id $card->{id}") or return;
	ok($checklist->{id},"checklist has an id ($checklist->{id})") or return;

	# try archiving one card
	# how???

	$item_args = {};
	for (0..2) {
		$item_args->{name} = "That thing $_";
		lives_ok(sub { $item = $t->post({ path => "checklists/$checklist->{id}/checkItems", query => $item_args }) },
			"Can create an item called $item_args->{name} on checklist id $checklist->{id}") or return;
		is($item_args->{name},$item->{name},"Got right name");
	}

	my ($archive_result);
	lives_ok(sub { $archive_result = $t->post({ path => "lists/$list_id/archiveAllCards" }) },
		"Can call lists/$list_id/archiveAllCards") or return;

	lives_ok(sub { $cards = $t->get({ path => "lists/$list_id/cards" }) },
		"Can get list of cards for list $list_id");
	is($cards,undef,"Got no cards for $list_id after cards were archived") 
		or do { diag(Dumper($cards)); return; };

	# check that we can still get info on a card that's archived
	my $a_card;
	lives_ok(sub { $a_card = $t->get({ path => "cards/$card->{id}" }); },
		"Can get info on archived card") or return;
	print Dumper($a_card);

}