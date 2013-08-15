package ImageSize::Controller::Sizer;
use Moose;
use namespace::autoclean;

use String::Random;
use Imager;
use LWP::Simple;
use File::Copy;
use Data::Dumper;

BEGIN {extends 'Catalyst::Controller::REST'; }

=head1 NAME

ImageSize::Controller::Sizer - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub resize : Local : ActionClass('REST') { }

=pod

=item resize_POST

pass in URL, or local file -  http://domain.name/images/image.jpg, file:///directory/
and dimensions - 1920×1080 - HD 1080, 1280 × 720 HD - 720, 1024 X 768 or custom
returns true if it got the file and resized, with a URL to the new image
Otherwise, returns false and an error string

Input Format: JSON as an ex:

{ imageURL => http://0:3000/static/images/TestAlbum/Images/6.jpg,
    width => 1280,
    height => 720,
}

=cut


sub resize_POST {
    my ( $self, $c ) = @_;
    
    #get the image, retrieve into uploadsdir
    $c->forward('getImage');
    #copy it, resize copy to thumbnail
    my $img = Imager->new( file => $c->config->{home} . '/root' . $c->stash->{tempname} )
        or die( Imager->errstr());
    #should handle errors better, and fix var names, but this is functional for now
    
    my $thumb = $img->scale(xpixels => 150, ypixels => 150);
    $thumb->write( file => $c->config->{home} . '/root' . $c->stash->{thumbname} );
    
    #resize image
    my $final = $img->scale(xpixels => $c->req->param('width'), ypixels => $c->req->param('height'));
    $final->write( file => $c->config->{home} . '/root' . $c->stash->{newfilename} );
    
    my $returnHash = {
        thumbnail => $c->stash->{thumbname},
        resized => $c->stash->{newfilename},
        complete => 1,
    };
    
    if ( $c->stash->{errorString} ) {
        $returnHash->{complete} = 0;
        $returnHash->{errorString} = $c->stash->{errorString}
    }
    else {
        #cleanup
        unlink($c->config->{home} . '/root' . $c->stash->{tempname});
    }
    
    $self->status_ok(
        $c,
        entity => $returnHash,
    );
}


sub makeFileName {
    my ( $filename ) = @_;

    my $rand = new String::Random;
    my $ext = $filename;
    $ext =~ s/^.+\.(\w{2,4})$/$1/;
    
    my $fn = $rand->randpattern("cCcC") . $rand->randregex('\w{10}');
    my $tempfilename = $fn . '_tmp.' . $ext;
    my $newfilename = $fn . '.' . $ext;
    my $thumbname = $fn . '_thumb.' . $ext;

    return ($newfilename,$thumbname,$tempfilename);
}

sub getImage: Private {
    my ( $self, $c ) = @_;
    
    my $imageURL = $c->req->param('imageURL');
    
    my $fn = $imageURL;
    
    unless ( $fn ) {
        $c->stash( 'errorString' => 'ImageURL was empty' );
        return;
    }
    unless (  $fn =~ /\/(.+?)\.(\w{2,4})$/ ) {
        $c->stash( 'errorString' => "ImageURL did not have a full path with file name $fn" );
        return;
    }
    
    my $ext = $2;
    
    my @pathitems = split('/',$1);

    my $lastIdx = $#pathitems;
    
    my $filename = $pathitems[$lastIdx] . '.' . $ext;
    
    my ($newfilename,$thumbname,$tempname) = makeFileName($filename);
    
    $c->log->info("home = " . $c->config->{home} . ", newfilename = $newfilename, url = $imageURL");
    $c->log->info("store to " . $c->config->{home} . '/root' . $c->config->{uploadsdir} . '/' . $newfilename);
 
    my $response;
    if ( $imageURL =~ /^\// ) {
        #local file, copy instead of store
        File::Copy::copy($c->config->{home} . '/root' . $imageURL, $c->config->{home} . '/root' . $c->config->{uploadsdir} . '/' . $tempname);
        $response = 200;
    }
    else {
        $response = getstore($imageURL, $c->config->{home} . '/root' . $c->config->{uploadsdir} . '/' . $tempname);
    }
    
    if ( $response == 200 ) {
        $c->stash( 
            newfilename     =>  $c->config->{uploadsdir} . '/' . $newfilename,
            thumbname       =>  $c->config->{uploadsdir} . '/' . $thumbname,
            tempname        =>  $c->config->{uploadsdir} . '/' . $tempname);
        $c->log->info("stored here");        
    }
    else {
        $c->log->error("Images was not stored - response $response");
        $c->stash( 'errorString' => 'Image was not stored response $response');
    }
}
    
    

=head1 AUTHOR

Paul Millard

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
