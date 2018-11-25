#!perl -w
use strict;
use Test::More;

use Imager::File::WEBP;
use Imager::Test qw(test_image);

my $im = test_image;

my $data;
ok($im->write(data => \$data, type => "webp"),
   "write single image");
ok(length $data, "actually wrote something");
is(substr($data, 0, 4), 'RIFF', "got a RIFF file");
is(substr($data, 8, 4), 'WEBP', "of WEBP flavour");

done_testing();
