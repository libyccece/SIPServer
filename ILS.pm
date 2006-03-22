#
# ILS.pm: Test ILS interface module
#

package ILS;

use Exporter;
use warnings;
use strict;
use Sys::Syslog qw(syslog);

use ILS::Item;
use ILS::Patron;
use ILS::Transaction;
use ILS::Transaction::Checkout;

our (@ISA, @EXPORT_OK);

@ISA = qw(Exporter);

my %supports = (
		'magnetic media' => 1,
		'security inhibit' => 0,
		'offline operation' => 0
		);

sub new {
    my ($class, $institution) = @_;
    my $type = ref($class) || $class;
    my $self = {};

    syslog("DEBUG", "new ILS '$institution'");
    $self->{institution} = $institution;

    return bless $self, $type;
}

sub institution {
    my $self = shift;

    return $self->{institution};
}

sub supports {
    my ($self, $op) = @_;

    return exists($supports{$op}) ? $supports{$op} : 0;
}

sub checkout_ok {
    return 1;
}

sub checkin_ok {
    return 0;
}

sub status_update_ok {
    return 1;
}

sub offline_ok {
    return 0;
}
#
# Checkout(patron_id, item_id, sc_renew):
#    patron_id & item_id are the identifiers send by the terminal
#    sc_renew is the renewal policy configured on the terminal
# returns a status opject that can be queried for the various bits
# of information that the protocol (SIP or NCIP) needs to generate
# the response.
#
sub checkout {
    my ($self, $patron_id, $item_id, $sc_renew) = @_;
    my ($patron, $item, $circ);

   $circ = new ILS::Transaction::Checkout;

    # BEGIN TRANSACTION
    $circ->{patron} = $patron = new ILS::Patron $patron_id;
    $circ->{item} = $item = new ILS::Item $item_id;

    $circ->{ok} = ($circ->{patron} && $circ->{item}) ? 1 : 0;

    if ($circ->{ok}) {
	$item->{patron} = $patron_id;
	push(@{$patron->{items}}, $item_id);
	$circ->{desensitize} = !$item->magnetic;
    }

    return $circ;
}

sub block_patron {
    my ($self, $patron_id, $card_retained, $blocked_card_msg) = @_;
    my $patron;

    $patron = new ILS::Patron $patron_id;

    if (!$patron) {
	syslog("WARNING", "ILS::block_patron: attempting to block non-existant patron '%s'", $patron_id);
	return undef;
    }

    foreach my $field ('charge_ok', 'renew_ok', 'recall_ok', 'hold_ok') {
	$patron->{$field} = 'N';
    }

    $patron->{screen_msg} = $blocked_card_msg || "Card Blocked.  Please contact library staff";

    return $patron;
}

1;
