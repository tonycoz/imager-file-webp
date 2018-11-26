#!perl -w
use strict;
use Test::More;

use Imager::File::WEBP;
use Imager::Test qw(test_image is_image_similar);

my $im = Imager->new;

{
  my @im = Imager->read_multi(file => "testimg/simple.webp", type => "webp");
  is(@im, 1, "read single image (using multi interface)");
  is_image_similar($im[0], test_image(), 2_000_000, "check for close match");
}

{
  my @im = Imager->read_multi(file => "testimg/simpalpha.webp", type => "webp");
  is(@im, 1, "read single alpha image (using multi interface)");
  my $check = Imager->new(xsize => 20, ysize => 20, channels => 4);
  $check->box(xmax => 9, color => [ 0, 0, 255, 128], filled => 1);
  $check->box(xmin => 10, color => [ 255, 255, 0, 192 ], filled => 1);
  is_image_similar($im[0], $check, 2_000_000, "check for close match");
}

done_testing();
