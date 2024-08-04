package ImageSize::Controller::Sizer;
use Moose;
use namespace::autoclean;


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

{ 
    imageURL    => 'http://0:3000/static/images/TestAlbum/Images/6.jpg',
    width       => 1280,
    height      => 720,
}

Output format: JSON:

{
    thumbnail   => 'http://localdomain/path/to/image_thumb.jpg',
    resized     => 'http://localdomain/path/to/image.jpg',
    complete    => 1,
}

If there were errors:
{
    complete    => 0,
    errorString => 'Text to display regarding error',
}

=cut


sub resize_POST {
    my ( $self, $c ) = @_;
    
    my $imageURL = $c->req->param('imageURL');
    
    unless ( $imageURL ) {
        $c->stash( 'errorString' => 'ImageURL was empty' );
        return;
    }
    
    my $image = $c->model('Image')->new({  
        imageUrl => $imageURL,
        localInfo => {
            home        => $c->config->{home},
            uploads     => $c->config->{uploadsdir},
            root        => '/root',
            logger      => $c->log,
            maxThumbSize    => $c->config->{max_thumb_size},
            width       => $c->req->param('width'),
            height      => $c->req->param('height'),
        },
    });

    my $returnHash = {
        errorString => '',
        complete    => 0,
    };
    
    if ( $image->resized ) {
        $returnHash = {
            thumbnail   => $image->imageInfo->{thumbfilepath},
            resized     => $image->imageInfo->{newfilepath},
            complete    => 1,
        };
        unlink($image->imageInfo->{tempname});
    }
    else {
        if ( $image->has_errors ) {
            $returnHash->{errorString} = '<ul><li>' . join( '<li>', @{ $image->errorStrings } ) . '</ul>';
        }
    }
    
    $self->status_ok(
        $c,
        entity => $returnHash,
    );
}
    

=head1 AUTHOR

Paul Millard

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
