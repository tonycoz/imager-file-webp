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

my ($riff, $fsize, $webp) = unpack("a4L<a4", $head);
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
      my ($ft, $mag, $width, $height) = unpack("a3a3S<S<", $cbody);
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
      print " ** body too small for 'VP8 '\n";
    }
  }
  elsif ($cfourcc eq 'VP8X') {
    if ($csize >= 10) {
      my ($flags, $res, $cwidth, $cheight) = unpack("Ca3a3a3", $cbody);
      my $res_a = ($flags & 0xC0);
      my $has_icc = ($flags & 0x20) ? "Yes" : "No";
      my $has_alpha = ($flags & 0x10) ? "Yes" : "No";
      my $has_exif = ($flags & 0x08) ? "Yes" : "No";
      my $has_xmp = ($flags & 0x04) ? "Yes" : "No";
      my $has_anim = ($flags & 0x02) ? "Yes" : "No";
      my $res_b = ($flags & 0x01);
      my $res_c = unpack("H*", $res);
      $cwidth = unpack("L<", "$cwidth\0");
      $cheight = unpack("L<", "$cheight\0");
      print <<EOS;
  Has ICC: $has_icc
  Has Alpha: $has_alpha
  Has EXIF: $has_exif
  Has XMP: $has_xmp
  Has Animation: $has_anim
  Canvas Witdh: $cwidth + 1
  Canvas Height: $cheight + 1
  Reserved: $res_a  $res_b  $res_c
EOS
    }
    else {
      print " ** body too small for 'VP8X'\n";
    }
  }
  elsif ($cfourcc eq 'ALPH') {
    if ($csize > 1) {
      my ($flags) = unpack("C", $cbody);
      my $pre = ($flags & 0x30) >> 4;
      my $filt = ($flags & 0xC0) >> 2;
      my $comp = ($flags & 0x03);
      my $leftover = $csize - 1;
      print <<EOS;
  Preprocessing: @{["None", "Level Reduction", "Unknown", "Unknown" ]}[$pre] ($pre)
  Filtering: @{["predictor = 0", "predictor = A", "predictor = B", "predictor = clip(A+B-C)"]}[$filt] ($filt)
  Compression: @{["None", "WebP Lossless", "Unknown", "Unknown" ]}[$comp] ($comp)
  Alpha bytes: $leftover
EOS
    }
  }
}
