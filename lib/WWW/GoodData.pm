package WWW::GoodData;

=head1 NAME

WWW::GoodData - Client library for GoodData REST-ful API

=head1 SYNOPSIS

  use WWW::GoodData;
  my $gdc = new WWW::GoodData;
  print $gdc->get_uri ('md', { title => 'My Project' });

=head1 DESCRIPTION

B<WWW::GoodData> is the client for GoodData JSON-based API
built atop L<WWW::GoodData::Agent> client agent, with focus
on usefullness and correctness of implementation.

It  provides code for navigating the REST-ful API structure as well as
wrapper funcitons for common actions.

=cut

use strict;
use warnings;

use WWW::GoodData::Agent;
use URI;

our $root = new URI ('https://secure.gooddata.com/gdc');

=head1 METHODS

=over 4

=item B<new> [PARAMS]

Create a new client instance.

You can optionally pass a hash reference with properties that would be
blessed, otherwise a new one is created. Possible properties include:

=over 8

=item B<agent>

A L<WWW::GoodData::Agent> instance to use.

=back

=cut

sub new
{
	my $class = shift;
	my $self = shift || {};
	bless $self, $class;
	$self->{agent} ||= new WWW::GoodData::Agent ($root);
	$self->{agent}->{error_callback} = \&error_callback;
	return $self;
}

# API hierarchy traversal Cache
our %links;
sub get_links
{
	my $self = shift;
	my $root = ref $_[0] ? shift : $root;
	my @path = map { ref $_ ? $_ : { category => $_ } } @_;
	my $link = shift @path;

	unless ($links{$root}) {
		my $response = $self->{agent}->get ($root);
		$links{$root} = $response->{about}{links};
	}

	my @matches = grep {
		my $this_link = $_;
		# Filter out those, who lack any of our keys or
		# hold a different value for it.
		not map { not exists $link->{$_}
			or not exists $this_link->{$_}
			or $link->{$_} ne $this_link->{$_}
			? 1 : () } keys %$link
	} @{$links{$root}};

	# Fully resolved
	return @matches unless @path;

	die 'Ambigious path' unless scalar @matches == 1;
	my $new_root = new URI ($matches[0]->{link});
	$new_root = $new_root->abs ($root);

	return $self->get_links ($new_root, @path);
}

=item B<links> PATH

Traverse the links in resource hierarchy following given PATH,
starting from API root (L</gdc> by default).

PATH is an array of dictionaries, where each key-value pair
matches properties of a link. If a plain string is specified,
it is considered to be a match against B<category> property:

  $gdc->get_links ('md', { 'category' => 'projects' });

The above call returns a list of all projects, with links to
their metadata resources.

=cut

sub links
{
	my @links = get_links @_;
	return @links if @links;
	%links = ();
	return get_links @_;
}

=item B<get_uri> PATH

Follows the same samentics as B<links>() call, but returns an
URI of the first matching resource instead of complete link
structure.

=cut

sub get_uri
{
	[links @_]->[0]{link};
}

=item B<login> EMAIL PASSWORD

Obtain a SST (login token).

=cut

sub login
{
	my $self = shift;
	my ($login, $password) = @_;

	$self->{login} = $self->{agent}->post ($self->get_uri ('login'),
		{postUserLogin => {
			login => $login,
			password => $password,
			remember => 0}});
}

=item B<projects>

Return array of links to project resources on metadata server.

=cut

sub projects
{
	shift->get_links (qw/md project/);
}

=item B<delete_project> IDENTIFIER

Delete a project given its identifier.

=cut

sub delete_project
{
	my $self = shift;
	my $project = shift;

	my $uri = $self->get_uri ('projects', { identifier => $project })
		or die "No such project: $project";
	$self->{agent}->delete ($uri);
}

=back

=head1 SEE ALSO

=over

=item *

L<https://secure.gooddata.com/gdc/> -- Browsable GoodData API

=item *

L<WWW::GoodData::Agent> -- GoodData API-aware user agent

=back

=head1 COPYRIGHT

Copyright 2011, Lubomir Rintel

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Lubomir Rintel C<lkundrak@v3.sk>

=cut

1;
