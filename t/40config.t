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

{
  my $cfg = Imager::File::WEBP::Config->new($im);
  ok($cfg->target_size(100_000), "set target_size");
  is($cfg->target_size, 100_000, "check target_size");
  ok(!$cfg->target_size(-1), "try a bad target_size");
  is($cfg->target_size, 100_000, "check target_size wasn't changed");

  ok($cfg->quality(50.5), "set quality")
    or diag(Imager->_error_as_msg);
  is($cfg->quality, 50.5, "check quality");
  ok(!$cfg->quality(101), "try a bad quality");
  is($cfg->quality, 50.5, "check quality wasn't changed");

  ok($cfg->hint("picture"), "set hint to picture");
  is($cfg->hint, "picture", "check it was set");
  ok(!$cfg->hint("xx"), "set hint to bad value");
  is($cfg->hint, "picture", "check hint wasn't changed");

  my $im = test_image();
  ok($im->settag(name => "webp_quality", value => 90.5),
     "set quality on check image");
  ok($cfg->update($im), "update from new image");
  is($cfg->quality, 90.5, "check update worked");
}

done_testing();
