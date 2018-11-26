#!perl -w
use strict;
use Test::More;

use Imager::File::WEBP;
use Imager::Test qw(test_image is_image_similar);
use lib 't/lib';
use TestImage qw(alpha_test_image);

my $im = Imager->new;

{
  my @im = Imager->read_multi(file => "testimg/simple.webp", type => "webp");
  is(@im, 1, "read single image (using multi interface)");
  is_image_similar($im[0], test_image(), 2_000_000, "check for close match");
  my ($format) = $im[0]->tags(name=>'i_format');
  is($format, 'webp', "check i_format tag");
}

{
  my @im = Imager->read_multi(file => "testimg/simpalpha.webp", type => "webp");
  is(@im, 1, "read single alpha image (using multi interface)");
  my $check = alpha_test_image();
  is_image_similar($im[0], $check, 2_000_000, "check for close match");
}

{
  my @im = Imager->read_multi(file => "testimg/anim.webp", type => "webp");
  is(@im, 2, "read 2 images with multi interface");
  is_image_similar($im[0], test_image(), 2_000_000, "check for close match");
  is_image_similar($im[1], alpha_test_image(), 2_000_000, "check for close match");
}

SKIP:
{
  my $im = Imager->new;
  ok($im->read(file => "testimg/simple.webp", type => "webp"),
     "read simple using single interface")
    or skip("No image read", 1);
  is_image_similar($im, test_image(), 2_000_000, "check for close match");
}

SKIP:
{
  my $im = Imager->new;
  ok($im->read(file => "testimg/anim.webp", type => "webp", page => 1),
     "read anim second image using single interface")
    or skip("No image read", 1);
  is_image_similar($im, alpha_test_image(), 2_000_000, "check for close match");
}

done_testing();
