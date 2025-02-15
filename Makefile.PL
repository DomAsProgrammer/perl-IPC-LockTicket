#!/usr/bin/env perl

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME            => q{IPC::LockTicket},
	VERSION_FROM    => 'lib/IPC/LockTicket.pm'
	);
