package Imager::File::WEBP;
use strict;
use Imager;
use vars qw($VERSION @ISA);

BEGIN {
  $VERSION = "0.001";

  require XSLoader;
  XSLoader::load('Imager::File::WEBP', $VERSION);
}

Imager->register_reader
  (
   type=>'webp',
   single => 
   sub { 
     my ($im, $io, %hsh) = @_;

     my $allow_incomplete = $hsh{allow_incomplete};
     defined $allow_incomplete or $allow_incomplete = 0;

     my $page = $hsh{page};
     defined $page or $page = 0;
     $im->{IMG} = i_readwebp($io, $allow_incomplete, $page);

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
     $im->_set_opts(\%hsh, "exif_", $im);

     unless (i_writewebp($im->{IMG}, $io)) {
       $im->_set_error(Imager->_error_as_msg);
       return;
     }
     return $im;
   },
   multiple =>
   sub {
     my ($class, $io, $opts, @ims) = @_;

     Imager->_set_opts($opts, "webp_", @ims);
     Imager->_set_opts($opts, "exif_", @ims);

     my @work = map $_->{IMG}, @ims;
     my $result = i_writewebp_multi($io, @work);
     unless ($result) {
       $class->_set_error($class->_error_as_msg);
       return;
     }

     return 1;
   },
  );

__END__

=head1 NAME

Imager::File::TIFF - read and write TIFF files

=head1 SYNOPSIS

  use Imager;

  my $img = Imager->new;
  $img->read(file=>"foo.tiff")
    or die $img->errstr;

  $img->write(file => "foo.tif")
    or die $img->errstr;

=head1 DESCRIPTION

Imager's TIFF support is documented in L<Imager::Files>.

=head1 AUTHOR

Tony Cook <tonyc@cpan.org>

=head1 SEE ALSO

Imager, Imager::Files.

=cut
