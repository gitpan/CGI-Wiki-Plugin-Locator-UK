package CGI::Wiki::Plugin::Locator::UK;

use strict;

use vars qw( $VERSION );
$VERSION = '0.02';

use Carp qw( croak );

=head1 NAME

CGI::Wiki::Plugin::Locator::UK - A CGI::Wiki plugin to manage UK location data.

=head1 DESCRIPTION

Access to and calculations using British National Grid location
metadata supplied to a CGI::Wiki wiki when writing a node. (For
converting between British National Grid co-ordinates and
latitude/longitude, you may wish to look at L<Geography::NationalGrid>.)

B<Note:> This is I<read-only> access. If you want to write to a node's
metadata, you need to do it using the C<write_node> method of
L<CGI::Wiki>.

=head1 SYNOPSIS

  use CGI::Wiki;
  use CGI::Wiki::Plugin::Locator::UK;

  my $wiki = CGI::Wiki->new;
  my $locator = CGI::Wiki::Plugin::Locator::UK->new( wiki => $wiki );

  $wiki->write_node( "Jerusalem Tavern",
                     "A good pub",
                     $checksum,
		     { os_x => 531674,
                       os_y => 181950
                     }
                    );

  # Just retrieve the co-ordinates.
  my ( $x, $y ) = $locator->coordinates( node => "Jerusalem Tavern" );

  # Find the straight-line distance between two nodes, in kilometres.
  my $distance = $locator->distance( from_node => "Jerusalem Tavern",
                                     to_node   => "Calthorpe Arms" );

  # Find all the things within 200 metres of a given place.
  my @others = $locator->find_within_distance( node   => "Albion",
                                               metres => 200 );

=head1 METHODS

=over 4

=item B<new>

  my $locator = CGI::Wiki::Plugin::Locator::UK->new( wiki => $wiki );

Mandatory argument - a CGI::Wiki object.

=cut

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self, $class;
    return $self->_init(@args);
}

sub _init {
    my ($self, %args) = @_;
    my $wiki = $args{wiki};
    unless ( $wiki && UNIVERSAL::isa( $wiki, "CGI::Wiki" ) ) {
        croak "No CGI::Wiki object supplied.";
    }
    $self->{wiki} = $wiki;
    return $self;
}

=item B<coordinates>

  my ($x, $y) = $locator->coordinates( node => "Jerusalem Tavern" );

Returns the OS x and y co-ordinates stored as metadata last time the
node was written.

=cut

sub coordinates {
    my ($self, %args) = @_;
    my $wiki = $self->{wiki};
    # This is the slightly inefficient but neat and tidy way to do it -
    # calling on as much existing stuff as possible.
    my %node_data = $wiki->retrieve_node( $args{node} );
    my %metadata  = %{$node_data{metadata}};
    return ($metadata{os_x}[0], $metadata{os_y}[0]);
}

=item B<distance>

  # Find the straight-line distance between two nodes, in kilometres.
  my $distance = $locator->distance( from_node => "Jerusalem Tavern",
                                     to_node   => "Calthorpe Arms" );

  # Or in metres.
  my $distance = $locator->distance(from_node => "Angel Station",
				    to_node   => "Duke of Cambridge",
				    unit      => "metres" );

Defaults to kilometres if C<unit> is not supplied or is not recognised.
Recognised units at the moment: C<metres>, C<kilometres>.

Returns C<undef> if one of the nodes does not exist, or does not have
both co-ordinates defined.

B<Note:> Works to the nearest metre. Well, actually, calls C<int> and
rounds down, but if anyone cares about that they can send a patch.

=cut

sub distance {
    my ($self, %args) = @_;

    $args{unit} ||= "kilometres";
    my $from_node = $args{from_node} or return undef;
    my $to_node   = $args{to_node}   or return undef;

    my @from = $self->coordinates( node => $from_node );
    my @to   = $self->coordinates( node => $to_node );
    $_ or return undef foreach @from, @to;

    my $metres = int( sqrt(   ($from[0] - $to[0])**2
                            + ($from[1] - $to[1])**2 ) + 0.5 );

    if ( $args{unit} eq "metres" ) {
        return $metres;
    } else {
        return $metres/1000;
    }
}

=item B<find_within_distance>

  # Find all the things within 200 metres of a given place.
  my @others = $locator->find_within_distance( node   => "Albion",
                                               metres => 200 );

Units currently understood: C<metres>, C<kilometres>.

=cut

sub find_within_distance {
    my ($self, %args) = @_;

    my $store = $self->{wiki}->store;
    my $dbh = eval { $store->dbh; }
      or croak "find_within_distance is only implemented for database stores";
    my $metres = $args{metres}
               || ($args{kilometres} * 1000)
               || croak "Please supply a distance";
    my ($sx, $sy) = $self->coordinates( node => $args{node} );

    # Only consider nodes within the square containing the circle of
    # radius $distance.  The SELECT DISTINCT is needed because we might
    # have multiple versions in the table.
    my $sql = "SELECT DISTINCT x.node
                FROM metadata AS x, metadata AS y
                WHERE x.metadata_type = 'os_x'
                  AND y.metadata_type = 'os_y'
                  AND x.metadata_value >= " . ($sx - $metres)
            . "   AND x.metadata_value <= " . ($sx + $metres)
            . "   AND y.metadata_value >= " . ($sy - $metres)
            . "   AND y.metadata_value <= " . ($sy + $metres)
            . "   AND x.node = y.node "
            . "   AND x.node != " . $dbh->quote($args{node});
    # Postgres is a fussy bugger.
    if ( ref $store eq "CGI::Wiki::Store::Pg" ) {
        $sql =~ s/metadata_value/metadata_value::integer/gs;
    }
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my @results;
    while ( my ($result) = $sth->fetchrow_array ) {
        my $dist = $self->distance( from_node => $args{node},
				    to_node   => $result,
				    unit      => "metres" );
        if ($dist && $dist <= $args{metres} ) {
            push @results, $result;
	}
    }
    return @results;
}

=head1 SEE ALSO

=over 4

=item * L<CGI::Wiki>

=item * L<Geography::NationalGrid>

=item * My test wiki that uses this plugin - L<http://the.earth.li/~kake/cgi-bin/cgi-wiki/wiki.cgi>

=back

=head1 AUTHOR

Kake Pugh (kake@earth.li).

=head1 COPYRIGHT

     Copyright (C) 2003 Kake Pugh.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CREDITS

Nicholas Clark found a very silly bug in a pre-release version, oops
:) Stephen White got me thinking in the right way to implement
C<find_within_distance>. Marcel Gruenauer helped me make
C<find_within_distance> work properly with postgres.

=cut


1;
