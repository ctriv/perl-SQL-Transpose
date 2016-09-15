use warnings;
use strict;
use Test::SQL::Transpose;
use Test::Differences;
use FindBin qw/$Bin/;

BEGIN {
    maybe_plan(1, 'SQL::Transpose::Parser::XML', 'SQL::Transpose::Producer::XML');
}

# It's very hard to read and modify YAML by hand. Thus we
# use an XML file for definitions, and generate a YAML from
# it in Makefile.PL, so we do not saddle the user with XML
# dependencies for testing. This test makes sure they do
# not drift apart.

use SQL::Transpose;

my $base_xml_fn     = "$Bin/data/roundtrip.xml";
my $autogen_yaml_fn = "$Bin/data/roundtrip_autogen.yaml";

my $orig_xml = _parse_to_xml($base_xml_fn,     'XML');
my $new_xml  = _parse_to_xml($autogen_yaml_fn, 'YAML');

eq_or_diff("$new_xml", "$orig_xml", 'YAML test schema matches original XML schema');

sub _parse_to_xml {
    my ($fn, $type) = @_;

    my $tr = SQL::Transpose->new;
    $tr->no_comments(1); # this will drop the XML header

    my $xml = $tr->translate(
        parser   => $type,
        file     => $fn,
        producer => 'XML',
    ) or die $tr->error;

    return $xml;
}
