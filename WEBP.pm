package Imager::File::WEBP;
use strict;
use Imager;
use vars qw($VERSION @ISA);

BEGIN {
  $VERSION = "0.004";

  require XSLoader;
  XSLoader::load('Imager::File::WEBP', $VERSION);
}

Imager->register_reader
  (
   type=>'webp',
   single => 
   sub { 
     my ($im, $io, %hsh) = @_;

     my $page = $hsh{page};
     defined $page or $page = 0;
     $im->{IMG} = i_readwebp($io, $page);

     unless ($im->{IMG}) {
       $im->_set_error(Imager->_error_as_msg);
       return;
     }

     return $im;
   },
   multiple =>
   sub {
     my ($io, %hsh) = @_;

     my @imgs = i_readwebp_multi($io);
     unless (@imgs) {
       Imager->_set_error(Imager->_error_as_msg);
       return;
     }

     return map bless({ IMG => $_, ERRSTR => undef }, "Imager"), @imgs;
   },
  );

Imager->register_writer
  (
   type=>'webp',
   single => 
   sub { 
     my ($im, $io, %hsh) = @_;

     $im->_set_opts(\%hsh, "i_", $im);
     $im->_set_opts(\%hsh, "webp_", $im);

     unless (i_writewebp($im->{IMG}, $io, $hsh{webp_config})) {
       $im->_set_error(Imager->_error_as_msg);
       return;
     }
     return $im;
   },
   multiple =>
   sub {
     my ($class, $io, $opts, @ims) = @_;

     Imager->_set_opts($opts, "webp_", @ims);

     my @work = map $_->{IMG}, @ims;
     my $result = i_writewebp_multi($io, $opts->{webp_config}, @work);
     unless ($result) {
       $class->_set_error($class->_error_as_msg);
       return;
     }

     return 1;
   },
  );

__END__

=head1 NAME

Imager::File::WEBP - read and write WEBP files

=head1 SYNOPSIS

  use Imager;

  my $img = Imager->new;
  $img->read(file=>"foo.webp")
    or die $img->errstr;

  # type won't be necessary if the extension is webp from Imager 1.008
  $img->write(file => "foo.webp", type => "webp")
    or die $img->errstr;

=head1 DESCRIPTION

Implements .webp file support for Imager.

Due to the limitations of C<webp> grayscale images are written as RGB
images.

=head1 TAGS

=over

=item *

C<webp_mode> - set when reading an image and used when writing.
Possible values:

=over

=item *

C<lossy> - write in lossy mode.  This is the default.

=item *

C<lossless> - write in lossless mode.

=back

=item *

C<webp_quality> - the lossy compression quality, a floating point
number from 0 (bad) to 100 (better).  Default: 80.

=back

If Imager::File::WEBP was built with Imager 1.010 then EXIF metadata
will also be read from the file.  See the description at
L<Imager::Files/JPEG>.

=head2 Animation tags

These only have meaning for files with more than one image.

Tags that can be set for the whole file, only the tag value from the
first image is used when writing:

=over

=item *

C<webp_loop_count> - the number of times to loop the animation.  When
writing an animation this is fetched only from the first image.  When
reading, the same file global value is set for every image read.
Default: 0.

=item *

C<webp_background> - the background color for the animation.  When
writing an animation this is fetched only from the first image.  When
reading, the same file global value is set for every image read.
Default: white.

=back

The following can be set separately for each image in the file:

=over

=item *

C<webp_left>, C<webp_top> - position of the frame within the animation
frame.  Only has meaning for multiple image files.  Odd numbers are
stored as the even number just below.  Default: 0.

=item *

C<webp_duration> - duration of the frame in milliseconds.  Default:
100.

=item *

C<webp_dispose> - the disposal method for the frame:

=over

=item *

C<background> - restore to the background before displaying the next
frame.

=item *

C<none> - leave the canvas as is when drawing the next frame.

=back

Default: C<background>.

=item *

C<webp_blend> - the blend method for the frame:

=over

=item *

C<alpha> - alpha combine the frame with canvas.

=item *

C<none> - replace the area under the image with the frame.

=back

If the frame has no alpha channel this option makes no difference.

Default: C<alpha>.

=back

=head1 INSTALLATION

To install Imager::File::WEBP you need Imager installed and you need
libwebp 0.5.0 or later and the libwebpmux distributed with libwebp.

=head1 TODO

These aren't intended immediately, but are possible future
enhancements.

=head2 Compression level support for lossless images

The simple lossless API doesn't include a compression level parameter,
which complicates this.  It may not be worth doing anyway.

=head2 Parse EXIF metadata

To fix this I'd probably pull imexif.* out of Imager::File::JPEG and
make it part of the Imager API.

Maybe also add extended EXIF/Geotagging via libexif or Exiftool.

=head2 Error handling tests (and probably implementation)

I think this is largely done.

=head1 AUTHOR

Tony Cook <tonyc@cpan.org>

=head1 SEE ALSO

Imager, Imager::Files.

=cut
