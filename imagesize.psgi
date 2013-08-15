use strict;
use warnings;

use ImageSize;

my $app = ImageSize->apply_default_middlewares(ImageSize->psgi_app);
$app;

