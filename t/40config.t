#!perl -w
use strict;
use Test::More;

use Imager::File::WEBP;
use Imager::Test qw(test_image is_image_similar);

my $im = test_image;

{
  my $cfg = Imager::File::WEBP::Config->new($im);
  ok($cfg, "make a default config");
  my $clone = $cfg->clone;
  ok($clone, "cloned it");
}
pass("hopefully destroyed it");

done_testing();
