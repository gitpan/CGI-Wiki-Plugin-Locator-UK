use strict;

use CGI::Wiki::TestConfig::Utilities;
use CGI::Wiki;

use Test::More tests => $CGI::Wiki::TestConfig::Utilities::num_stores;

my %stores = CGI::Wiki::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
    SKIP: {
      skip "$store_name storage backend not configured for testing", 1
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $dbname = $store->dbname;
      my $dbuser = $store->dbuser;
      my $dbpass = $store->dbpass;

      # Clear out the test database, then set up tables afresh.
      my $setup_class = "CGI::Wiki::Setup::$store_name";
      eval "require $setup_class";
      {
        no strict "refs";
        &{"$setup_class\:\:cleardb"}($dbname, $dbuser, $dbpass);
        &{"$setup_class\:\:setup"}($dbname, $dbuser, $dbpass);
      }
      pass "$store_name test backend set up successfully";
    }
}
