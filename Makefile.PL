use ExtUtils::MakeMaker;

WriteMakefile( NAME         => "CGI::Wiki::Plugin::Locator::UK",
	       VERSION_FROM => "lib/CGI/Wiki/Plugin/Locator/UK.pm",
	       PREREQ_PM    => { 'CGI::Wiki' => 0.23,#unbuggy metadata/testutls
			         'Test::More' => 0,
				 'Carp' => 0
                               },
               clean => { FILES => "t/sqlite-test.db t/sii-db-file-test.db" }
	     );

