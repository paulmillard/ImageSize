package ImageSize::Model::Image;
use Moose;
use namespace::autoclean;

use String::Random;
use Imager;
use LWP::Simple;
use File::Copy;
use Data::Dumper;

extends 'Catalyst::Model';

=head1 NAME

ImageSize::Model::Image - Catalyst Model

=head1 DESCRIPTION

Model to handle the IMage processing

=head1 AUTHOR

Paul Millard

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 Attributes

=over

=item imageUrl

Require String containing URL for image to be fetched

=cut

has 'imageUrl' => (
    isa => 'Str',
    is  => 'ro',
);

=pod

=item localInfo

Hash of information passed to the Image object

=cut
    
has 'localInfo' => (
    isa     => 'HashRef',
    is      => 'rw',
);

=pod

=item imageInfo

gets the full image info after all processing

=cut

has 'imageInfo' => (
    traits   => ['Hash'],
    isa => 'HashRef',
    is  => 'ro',
    handles => {
        set_info    => 'set',
        get_info    => 'get',
    },
);

=pod

=item resized

True or False if the image was resized.  The main method to call

=cut
    
has 'resized' => (
    isa => 'Bool',
    is  => 'rw',
    lazy    => 1,
    builder => '_buildImage',
);


=pod

=item errorStrings

if errors occur during processing, set them here

=cut

has 'errorStrings'  => (
    traits  => ['Array'],
    isa     => 'ArrayRef',
    is      => 'rw',
    default => sub { [] },
    handles => {
        has_errors  => 'count',
        add_error   => 'push',
    }
);


=head1 METHODS

=cut


=head2 Private METHODS

=item _buildImage

Run the basic mechanics to get the image and resize the image, populate the information on the image

=cut

sub _buildImage {
    my ( $self ) = @_;

my $log = $self->localInfo->{logger};
warn("full url = " . $self->imageUrl);
warn(" home = " . $self->localInfo->{home});

    unless ( $self->_getImageNames ) {
        return 0;
    }
      
    unless ( $self->_retrieveImage ) {
        return 0;
    }
    
    #copy and save image, create thumb
    unless ( $self->_resizeImage ) {
        return 0;
    }
    return 1;
}

=pod 

=item _getImageNames

get all the image names for saving the images and storing in attribute localInfo
self->imageInfo = {
    home        => '/home/paulm/projects/imageSize',
    rootdir     => '/home/paulm/projects/imageSize/root',
    uploadsdir  => '/home/paulm/projects/iamgeSize/root/static/resizeimages',
    newfilename => '/home/paulm/projects/iamgeSize/root/static/resizeimages/newfilename.jpg',
    tempfilename => '/home/paulm/projects/iamgeSize/root/static/resizeimages/tempfilename.jpg',
    thumbfilename => '/home/paulm/projects/iamgeSize/root/static/resizeimages/newfilename_thumb.jpg',
    };
    

=cut

sub _getImageNames {
    my ( $self ) = @_;
        
    my $imageURL = $self->imageUrl;
    
    unless ( $imageURL =~ /\/(.+?)\.(\w{2,4})$/ ) {
        $self->add_error("ImageURL did not have a full path with file name $imageURL");
    }
    
    my $ext = $2;
    
    my @pathitems = split('/',$1);

    my $lastIdx = $#pathitems;
    
    my $filename = $pathitems[$lastIdx] . '.' . $ext;
    
    my ($newfilename,$thumbname,$tempname) = _makeFileName($filename);
    
    my $log = $self->localInfo->{logger};
    
    my $homedir = $self->localInfo->{home};
    $self->set_info( rootdir => $homedir . $self->localInfo->{root});
    $self->set_info( uploadsdir => $self->imageInfo->{rootdir} . $self->localInfo->{uploads});
    $self->set_info(
        newfilename     => $self->imageInfo->{uploadsdir} . '/' . $newfilename,
        tempfilename    => $self->imageInfo->{uploadsdir} . '/' . $tempname,
        thumbfilename   => $self->imageInfo->{uploadsdir} . '/' . $thumbname,
        thumbfilepath   => $self->localInfo->{uploads} . '/' . $thumbname,
        newfilepath     => $self->localInfo->{uploads} . '/' . $newfilename,
    );

    $log->info("home = " . $homedir . ", newfilename = $newfilename, imageUrl = $imageURL");
    $log->info("store to " . $self->imageInfo->{newfilename});
    my $imageInfo = $self->imageInfo;
    $log->info("all of localinfo = " . Dumper( $imageInfo ));
        
    return 1;
}

=pod 

=item _retrieveImage

Run the basic mechanics to get the image and resize the image, populate the information on the image

=cut       

sub _retrieveImage {
    my ( $self ) = @_;
 
    my $response;
    if ( $self->imageUrl =~ /^\// ) {
        #local file, copy instead of store
        File::Copy::copy($self->imageInfo->{rootdir} . $self->imageUrl, $self->imageInfo->{tempfilename});
        $response = 200;
    }
    else {
        $response = LWP::Simple::getstore($self->imageUrl, $self->imageInfo->{tempfilename});
    }
    
    my $log = $self->localInfo->{logger};   
    unless ( $response == 200 ) {
        $log->error("Images was not stored - response $response");
        $self->add_error("Image was not stored response $response");
        return 0;
    }
    return 1;
}    

=pod 

=item _resizeImage

Run the basic mechanics to get the image and resize the image, populate the information on the image

=cut 

sub _resizeImage {
    my ( $self ) = @_;

    my $img = Imager->new( file => $self->imageInfo->{tempfilename} )
        or $self->add_error( 'Error saving image: ' . Imager->errstr() );
    
    if ( $self->has_errors ) { return 0; }  #could throw exceptions
    
    my $thumb = $img->scale( xpixels => $self->localInfo->{maxThumbSize}, ypixels => $self->localInfo->{maxThumbSize} );
    $thumb->write( file => $self->imageInfo->{thumbfilename} );
    
    #resize image
    my $final = $img->scale(xpixels => $self->localInfo->{width}, ypixels => $self->localInfo->{height});
    $final->write( file => $self->imageInfo->{newfilename} );  
    
    return 1;
}

=head2 Local METHODS

=item makeFileName

Given a filename, make a thumb name, a temporary stored file name for the
 original and the actual resized filename

=cut

sub _makeFileName {
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


__PACKAGE__->meta->make_immutable;

1;