#
# Sip.pm: General Sip utility functions
#

package Sip;

use strict;
use warnings;
use English;
use Exporter;

use Sys::Syslog qw(syslog);
use POSIX qw(strftime);

use Sip::Constants qw(SIP_DATETIME);
use Sip::Checksum qw(checksum);

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(y_or_n timestamp add_field maybe_add denied sipbool
		    boolspace write_msg
		    $error_detection $protocol_version $field_delimiter
		    $last_response);

our %EXPORT_TAGS = (
		    all => [qw(y_or_n timestamp add_field maybe_add
			       denied sipbool boolspace write_msg
			       $error_detection $protocol_version
			       $field_delimiter $last_response)]);


our $error_detection = 0;
our $protocol_version = "1.00";
our $field_delimiter = '|'; 	# Protocol Default

# We need to keep a copy of the last message we sent to the SC,
# in case there's a transmission error and the SC sends us a
# REQUEST_ACS_RESEND.  If we receive a REQUEST_ACS_RESEND before
# we've ever sent anything, then we are to respond with a 
# REQUEST_SC_RESEND (p.16)

our $last_response = '';

sub timestamp {
    my $time = $_[0] || time();

    return strftime(SIP_DATETIME, localtime($time));
}

#
# add_field(field_id, value)
#    return constructed field value
#
sub add_field {
    my ($field_id, $value) = @_;

    if (!defined($value)) {
	syslog("LOG_DEBUG", "add_field: Undefined value being added to '%s'",
	       $field_id);
    }
    return $field_id . $value . $field_delimiter;
}
#
# maybe_add(field_id, value):
#    If value is defined and non-empty, then return the
#    constructed field value, otherwise return the empty string
#
sub maybe_add {
    my ($fid, $value) = @_;

    return (defined($value) && $value) ? add_field($fid, $value) : '';
}

#
# denied($bool)
# if $bool is false, return true.  This is because SIP statuses
# are inverted:  we report that something has been denied, not that
# it's permitted.  For example, 'renewal priv. denied' of 'Y' means
# that the user's not permitted to renew.  I assume that the ILS has
# real positive tests.
# 
sub denied {
    my $bool = shift;

    if (!$bool || ($bool eq 'N') || $bool eq 'False') {
	return 'Y';
    } else {
	return ' ';
    }
}

sub sipbool {
    my $bool = shift;

    if (!$bool || ($bool =~/^false|n|no$/i)) {
	return('N');
    } else {
	return('Y');
    }
}

#
# boolspace: ' ' is false, 'Y' is true. (don't ask)
# 
sub boolspace {
    my $bool = shift;

    if (!$bool || ($bool eq 'N' || $bool eq 'False')) {
	return ' ';
    } else {
	return 'Y';
    }
}


#
# write_msg($msg, $server)
#
# Send $msg to the SC.  If error detection is active, then 
# add the sequence number (if $seqno is non-zero) and checksum
# to the message, and save the whole thing as $last_response
#

sub write_msg {
    my ($self, $msg, $server) = @_;
    my $cksum;

    if ($error_detection) {
	if ($self->{seqno}) {
	    $msg .= 'AY' . $self->{seqno};
	}
	$msg .= 'AZ';
	$cksum = checksum($msg);
	$msg .= sprintf('%4X', $cksum);
    }

    syslog("LOG_DEBUG", "OUTPUT MSG: '$msg'");

    print "$msg\r";
    $last_response = $msg;
}

1;
