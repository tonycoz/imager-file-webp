#!perl -w
use strict;

my $file = shift
  or die "Usage: $0 filename\n";

open my $fh, "<", $file
  or die "Cannot open file $file: $!\n";
binmode $fh;

# RIFF header
my $head;
read($fh, $head, 12) == 12
  or die "Cannot read RIFF header\n";

my ($riff, $fsize, $webp) = unpack("A4L<A4", $head);
print <<EOS;
Header:
  RIFF: $riff
  Size: $fsize
  WEBP: $webp
EOS

my $chead;
while (read($fh, $chead, 8) == 8) {
  my ($cfourcc, $csize) = unpack("a4L<", $chead);
  my $cbody = "";
  if ($csize) {
    read($fh, $cbody, $csize) == $csize
      or die "Cannot read chunk body for $cfourcc\n";
  }
  (my $disp4cc = $cfourcc) =~ s/([^!-~])/ sprintf("\\x%02x", ord($1)) /eg;
  print "Chunk: '$disp4cc' ($csize bytes)\n";
  if ($cfourcc eq 'VP8 ') {
    if ($csize >= 10) {
      my ($ft, $mag, $width, $height) = unpack("A3A3S<S<", $cbody);
      $ft = "$ft\0";
      $ft = unpack("L<", $ft);
      my $frame_type = ($ft >> 23) & 1 ? "inter" : "key";
      my $version = ($ft >> 20) & 7;
      my $show_frame = ($ft >> 19) & 1;
      $ft &= 0x7FFFF;
      my $mag_status = ($mag eq "\x9d\x01\x2a") ? "Good" : "Bad";
      my $disp_mag = unpack "H*", $mag;
      my $hscale = ($width >> 14) & 3;
      my $vscale = ($height >> 14) & 3;
      $width &= 0x3fff;
      $height &= 0x3fff;
      print <<EOS;
  Type: $frame_type
  Version: $version
  Show Frame: $show_frame
  Magic: $mag_status ($disp_mag)
  Dim: ${width}w x ${height}h
  Scale: $hscale x $vscale
  First size: $ft
EOS
    }
    else {
      print " ** body tool small for 'VP8 '\n";
    }
  }
}
