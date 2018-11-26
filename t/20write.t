#!perl -w
use strict;
use Test::More;

use Imager::File::WEBP;
use Imager::Test qw(test_image is_image_similar);
use lib 't/lib';
use TestImage qw(alpha_test_image);

{
  my $im = test_image;

  my $data;
  ok($im->write(data => \$data, type => "webp"),
     "write single image");
  ok(length $data, "actually wrote something");
  is(substr($data, 0, 4), 'RIFF', "got a RIFF file");
  is(substr($data, 8, 4), 'WEBP', "of WEBP flavour");
}

SKIP:
{
  my $im = test_image()->convert(preset => "gray");
  my $data;
  ok($im->write(data => \$data, type => "webp"),
     "write grayscale image")
    or skip "failed to write gray", 1;
  ok(length $data, "actually wrote something");
  my $im2 = Imager->new;
  ok($im2->read(data => \$data, type => "webp"),
     "read it back in")
    or skip "Failed to read it back", 1;
  # WEBP doesn't store grayscale
  my $check = $im->convert(preset => "rgb");
  is_image_similar($im2, $check, 200_000, "check it's similar");
}

SKIP:
{
  my $im = alpha_test_image();
  my $data;
  ok($im->write(data => \$data, type => "webp"),
     "write alpha image")
    or skip "Failed to write RGB with alpha", 1;
  my $im2 = Imager->new;
  ok($im2->read(data => \$data, type => "webp"),
     "read it back in")
    or skip "Failed to read it", 1;
  is_image_similar($im2, $im, 2_000_000, "check it's similar");
}

done_testing();
