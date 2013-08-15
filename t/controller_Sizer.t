use strict;
use warnings;
use Test::More;


use Catalyst::Test 'ImageSize';
use ImageSize::Controller::Sizer;

ok( request('/sizer')->is_success, 'Request should succeed' );
done_testing();
