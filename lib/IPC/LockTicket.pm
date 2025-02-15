#!/usr/bin/env perl

=begin meta_information

	License:		GPLv3 - see license file or http://www.gnu.org/licenses/gpl.html
	Program-version:	<see below>
	Description:		Libriary for IPC and token based lock mechanism.
	Contact:		Dominik Bernhardt - domasprogrammer@gmail.com or https://github.com/DomAsProgrammer

=end meta_information

=begin license

	Transport data between applications (IPC) via Storable library
	Copyright (C) 2023  Dominik Bernhardt

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.

=end license

=begin version_history

	v0.1 Beta
	I often had problems installing IPC::Sharable on dif-
	ferent platforms.
	So I built this library runable with only (Enterprise
	Linux) default Perl installation.

	v0.2 Beta
	Missing control added

	v0.2.1 Beta
	Extended how_to

	v1
	Bugfixes and release

	v1.1
	Now protects content of the file, only accessible by
	owner.

	v1.2
	Better target name handling.
	Enable user to use a second argument for manipulating
	chmod.

	v1.3
	Solved DESTROY bug

	v1.4
	Proper error message on missing lock file.
	Speed improvement by NOT sleeping

	v1.4.1
	Just some prettier output.
	
	v1.5
	Renamed

	v1.5.1
	Fewer output

	v1.6
	Read/write permission check.

	v1.6.1
	Read/write permission bug solved.
	Better working DESTROY function.

	v1.6.2
	False coded bol_AllowMultiple corrected.

	v1.6.3
	Code quality increased.
	Added dependency: boolean and Try

	v1.6.3.1
	Added coments

	v2.0
	Significant changes!
	Renamed
	Now working with a FIFO array, but nothing should change
	for the lib user.

	v2.1
	Some bugfixes.

	v2.2
	Implemented Carp and Exporter.
	Declared version.

	v2.3
	Used END block to properly end the program.

	v2.4
	Switched to Perl v5.40.0, removed Try and replaced by
	feature q{try}

	v2.5
	Perl v5.40.0 also supports boolean values nativly.
	Removed boolean and used builtin's true and false.

	v2.6
	Bugfix of lock_retrieve() on scrambled files.

	v2.7
	Detection and warning of orphan lock files.

	v2.8
	New terminology
	Compatibility layer

	v2.9
	Removed compatibility layer

=end version_history

=head1 HOW TO

 use IPC::LockTicket;

 my $object	= IPC::LockTicket->New(qq{name}, <chmod num>);	# For SPEED:	Creates a shared handle within
								# /dev/shm (allowed symbols: m{^[a-z0-9]+$}i)
								# name like name

 my $object	= IPC::LockTicket->New(qq{/absolute/path.file}, <chmod num>)
								# For STORAGE:	Creates a shared handle at the
								# given path (must be a file name)

 $bol_succcess	= $object->MainLock(1);				# For MULTIPLE usage: allows calling MainLock()
								# multiple times on same file to allow IPC even
								# if it's not from a fork (applies only on same
								# name or file) i.e. it's not failing on
								# MainLock() if file exists

 $bol_succcess	= $object->MainLock();				# Creates shm/lock-file or if existing and
								# MULTIPLE is active for file and new object
								# it implements the PID

 $bol_succcess	= $object->TokenLock();			# Get a ticket to queue up - blocks until it's
								# our turn

 $bol_succcess	= $object->SetCustomData($reference);		# Save any data as reference - be aware this
								# decreases speed and you fastly run out of
								# space

 $reference	= $object->GetCustomData();			# Load custom data block

 $bol_succcess	= $object->TokenUnlock();			# We're done and next one's turn is now

 $bol_succcess	= $object->MainUnlock();			# Removes PID from lock file on MULTIPLE. If
								# no more PIDs are within the lockfile it re-
								# moves the lock file as well.
								# Hint: The user of the library must take
								# care when to MainUnlock() e.g. wait until
								# all child processes died.

=begin comment

	V A R I A B L E  N A M I N G

	str	string
	 L sql	sql code
	 L cmd	command string
	 L ver	version number
	 L bin	binary data, also base64
	 L hex  hex coded data
	 L uri	path or url

	int	integer number
	 L cnt	counter
	 L pid	process id number
	 L tsp	seconds since period

	flt	floating point number

	bol	boolean

	mxd	unkown data (mixed)

	ref	reference
	 L rxp	regular expression
	 L are	array reference
	 L dsc	file discriptor (type glob)
	 L sub	anonymous subfunction	- DO NO LONGER USE, since Perl v5.26 functions can be declared lexically non-anonymous!
	 L har	hash array reference
	  L tbl	table (a hash array with PK as key OR a multidimensional array AND hash arrays as values)
	  L obj	object (very often)

=end comment

=cut

##### C L A S S  D E F I N I T I O N #####
package IPC::LockTicket;

##### L I B R I A R I E S #####

use strict;
use warnings;
use Storable qw(store retrieve lock_store lock_retrieve);	# Base for this library
use Time::HiRes;
use feature qw(try unicode_strings current_sub fc);
use open qw(:std :encoding(UTF-8));				# Full UTF-8 support
use utf8;							# Full UTF-8 support
use List::Util qw(first);
use Carp;
use Exporter;
### MetaCPAN
use builtin qw(true false);

BEGIN {	# Good practice of Exporter but we don't have anything to export
	our @EXPORT_OK	= ();
	our $VERSION	= q{2.9};
	}

END {
	_EndProcedure();
	}

$SIG{INT}		= \&_EndProcedure;
$SIG{TERM}		= \&_EndProcedure;


##### D E C L A R A T I O N #####
$ENV{LANG}		= q{C.UTF-8};
$ENV{LANGUAGE}		= q{C.UTF-8};
my @obj_EndSelf		= ();


##### M E T H O D S #####

sub new { goto &New; } # Keep regular naming for Perl objects
sub New {
	my $str_Class		= shift;
	my $obj_self	= {
		_uri_Path			=> shift,	# Path or name for Storable
		_int_Permission			=> shift,	# Permissons for the created file
		_pid_Parent			=> $$,
		_har_Data		=> {
			bol_AllowMultiple	=> false,	# Allows multiple locks on same file
			are_PIDs		=> [],		# MainLock() mechanism ; list of parents
			ref_CustomData		=> undef,	# Place to save data for lib user
			are_Token		=> [		# Array for FIFO handling
				#{
					# _pid_Agent	=> PID,
					# _pid_Parent	=> PID,
					#},
				],
			},
		};

	# If name is not a path or a name with prohibited characters
	if ( $obj_self->{_uri_Path}
	&& $obj_self->{_uri_Path} =~ m{^[-_a-z0-9]+$}i ) {
		my $bol_WorkingDirFound	= false;

		# Find a fitting directory
		test_dir:
		foreach my $str_Dir ( qw( /dev/shm /run/shm /run /tmp ) ) {
# WORK This is for Linux. Where shall this located on FreeBSD?
			if ( -d $str_Dir
			&& -w $str_Dir ) {
				$obj_self->{_uri_Path}		= qq{$str_Dir/IPC__LockTicket-Shm_$obj_self->{_uri_Path}};
				$bol_WorkingDirFound		= true;
				last(test_dir);
				}
			}

		# Stop if no fitting dir was found
		if ( ! $bol_WorkingDirFound ) {
			my $str_Caller	= (caller(0))[0];
			croak qq{$str_Caller(): Can't find any suitable directory\nIs this a systemd *NIX?\n};
			}
		}

	if ( &_Check($obj_self) ) {
		bless($obj_self, $str_Class);
		push(@obj_EndSelf, $obj_self);
		return($obj_self);
		}

	return(undef);
	}

# Similar to MainUnlock, but without blocking tokens
sub DESTROY {
	my $obj_self		= shift;

	# Only remove PID / lock file if the requesting process has created it
	if ( -e $obj_self->{_uri_Path}
	&& grep { $$ == $_ } $obj_self->_GetPIDs() ) {

		# Obsolete, doing the same as MainUnlock() while we already have a function for this purpose
		my @int_PIDs	= do {
			local $SIG{CLD}		= q{IGNORE};
			local $SIG{CHLD}	= q{IGNORE};

			grep { kill(0 => $_) } grep { $_ != $$ } $obj_self->_GetPIDs();
			};
		# Get running PIDs from lock file which are not the current process
		# to check if this process is the last one.

		# If there are other processes running
		if ( @int_PIDs
		&& $obj_self->_MultipleAllowed()
		&& open(my $fh, "<", $obj_self->{_uri_Path}) ) {
			flock($fh, 2);

			$obj_self->{_har_Data}	= retrieve($obj_self->{_uri_Path});

			# Calculate new data - this is needed, because flock() might have delayed the former request
			$obj_self->{_har_Data}->{are_PIDs}	= [ do {
				local $SIG{CLD}			= q{IGNORE};
				local $SIG{CHLD}		= q{IGNORE};

				grep { kill(0 => $_) } grep { $_ != $$ } @{$obj_self->{_har_Data}->{are_PIDs}};
				} ];

			store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

			my $str_Caller	= (caller(0))[3];
			close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};

			# If we exited as last process we now can delete the file
			if ( ! @{$obj_self->{_har_Data}->{are_PIDs}} ) {
				unlink($obj_self->{_uri_Path});
				}
			}
		# If we are the last exiting process
		else {
			unlink($obj_self->{_uri_Path});
			}
		}

	return(true);
	}

sub _Check {
	my $obj_self		= shift;
	my $str_Errors		= '';

	if ( $obj_self->{_uri_Path}
	&& -s $obj_self->{_uri_Path}
	&& open(my $fh, "<", $obj_self->{_uri_Path}) ) {
		flock($fh, 2);

		# Test if file is readable
		try {
			retrieve($obj_self->{_uri_Path})
			}
		catch ($str_Error) {
			$str_Errors	.= qq{"$obj_self->{_uri_Path}": Mailformed shared memory file.\n$str_Error\n};
			}

		my $str_Caller	= (caller(0))[3];
		close($fh) or $str_Errors .= qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};
		}
	# User failure
	elsif ( ! $obj_self->{_uri_Path} ) {
		my $str_Caller	= (caller(0))[3];
		$str_Errors		.= qq{$str_Caller(): Missing argument!\n};
		}
	# If open() failes
	elsif ( -s $obj_self->{_uri_Path} ) {
		my $str_Caller	= (caller(0))[3];
		$str_Errors		.= qq{$str_Caller(): Unable to open "$obj_self->{_uri_Path}"!\n};
		}

	# Some more fine tuning
	if ( $obj_self->{_uri_Path}
	&& -d $obj_self->{_uri_Path} ) {
		$str_Errors	.= qq{"$obj_self->{_uri_Path}": A folder can't be a share memory file!\n};
		}
	if ( $obj_self->{_uri_Path} !~ m{^\.?\.?/.+$} ) {
		$str_Errors	.= qq{"$obj_self->{_uri_Path}": is an inadequate path or name!\n};
		}

	# Protect file if not set other wise
	if ( ! defined($obj_self->{_int_Permission}) ) {
		$obj_self->{_int_Permission}	= 0600;
		}

	# Check permissions
	if ( -e $obj_self->{_uri_Path}
	&& ! -r $obj_self->{_uri_Path} ) {
		$str_Errors	.= qq{"$obj_self->{_uri_Path}": No read permission.\n};
		}
	if ( -e $obj_self->{_uri_Path}
	&& ! -w $obj_self->{_uri_Path} ) {
		$str_Errors	.= qq{"$obj_self->{_uri_Path}": No write permission.\n};
		}

	if ( $str_Errors ) {
		croak $str_Errors;
		}

	return(true);
	}

# Returns an array of integers which represents all registered PIDs of current lock file
sub _GetPIDs {
	my $obj_self		= shift;

	try {
		$obj_self->{_har_Data}	= lock_retrieve($obj_self->{_uri_Path});
		}
	catch ($str_Error) {
		carp qq{"$obj_self->{_uri_Path}": Mailformed shared memory file.\n$str_Error\n};
		return(undef);
		}

	return(@{$obj_self->{_har_Data}->{are_PIDs}});
	}

# Save a array of integer
sub _SetPIDs {
	my $obj_self		= shift;
	my @int_PIDs		= @_;

	if ( open(my $fh, "<", $obj_self->{_uri_Path}) ) {
		flock($fh, 2);

		$obj_self->{_har_Data}			= retrieve($obj_self->{_uri_Path});

		$obj_self->{_har_Data}->{are_PIDs}	= [ @int_PIDs ];

		store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

		my $str_Caller	= (caller(0))[3];
		close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};
		}

	return(true);
	}

# Returns boolean value
sub _MultipleAllowed {
	my $obj_self		= shift;

	try {
		$obj_self->{_har_Data}	= lock_retrieve($obj_self->{_uri_Path});
		}
	catch ($str_Error) {
		carp qq{"$obj_self->{_uri_Path}": Mailformed shared memory file.\n$str_Error\n};
		return(undef);
		}

	return($obj_self->{_har_Data}->{bol_AllowMultiple});
	}

# Creates the lock file
sub MainLock {
	my $obj_self		= shift;
	my $bol_MultipleAllowed	= shift;

	# If the file exists
	if ( -e $obj_self->{_uri_Path}
	&& $obj_self->_Check() ) {	# Dies in _Check if failed
		# If multiple is allowed we register our PID
		if ( $bol_MultipleAllowed
		&& $obj_self->_MultipleAllowed() ) {
			$obj_self->TokenLock();

			my @int_PIDs	= $obj_self->_GetPIDs();

			if ( grep { $_ == $$ } @int_PIDs ) {
				carp qq{WARNING: Same process tried to MainLock() again.\n};
				$obj_self->TokenUnlock();
				return(false);
				}
			else {
				$obj_self->_SetPIDs( @int_PIDs, $$ );
				}

			$obj_self->TokenUnlock();
			return(true);
			}
		# Or it must be exclusive
		else {
			$obj_self->TokenLock();
			my @int_PIDs	  	= $obj_self->_GetPIDs();

			local $SIG{CLD} 	= q{IGNORE};
			local $SIG{CHLD}	= q{IGNORE};

			# Did we lock up?
			if ( grep { $$ == $_ } @int_PIDs ) {
				carp qq{WARNING: Same process tried to MainLock() again.\n};
				$obj_self->TokenUnlock();
				return(false);
				}
			# There are processes running on this lock file
			elsif ( grep { kill(0 => $_) } @int_PIDs ) {
				$obj_self->TokenUnlock();
				return(false);
				}
			else {
				carp qq{ERROR: Was the former instance not exited porperly?\nOrphan lock file found: "$obj_self->{_uri_Path}".};
				return(false);
				}
			}
		}
	# Create file and write our format
	elsif ( ! -e $obj_self->{_uri_Path} ) {
		if ( open(my $fh, ">", $obj_self->{_uri_Path}) ) {
			close($fh);

			chmod($obj_self->{_int_Permission}, $obj_self->{_uri_Path});

			$obj_self->{_har_Data}->{bol_AllowMultiple}		= ( $bol_MultipleAllowed ) ? true : false;
			$obj_self->{_pid_Parent}				= $$;
			push(@{$obj_self->{_har_Data}->{are_PIDs}}, $$);

			lock_store($obj_self->{_har_Data}, $obj_self->{_uri_Path});
			}
		else {
			return(false);
			}
		}
	else {
		return(false);
		}

	return(true);
	}

# Removes lock file or the PID from those
sub MainUnlock {
	my $obj_self		= shift;

	if ( ! -e $obj_self->{_uri_Path} ) {
		my $str_Caller	= (caller(0))[3];
		croak qq{$str_Caller(): Lock file missing\nHave you ever called MainLock() ?\n};
		}

	if ( $obj_self->_MultipleAllowed() ) {
		my @int_PIDs	= ();

		$obj_self->TokenLock();

		@int_PIDs	= do {
			local $SIG{CLD}		= q{IGNORE};
			local $SIG{CHLD}	= q{IGNORE};

			grep { kill(0 => $_) } grep { $_ != $$ } $obj_self->_GetPIDs();
			};

		if ( @int_PIDs ) {
			$obj_self->_SetPIDs(@int_PIDs);
			$obj_self->TokenUnlock();
			}
		else {
			unlink($obj_self->{_uri_Path});
			}

		}
	else {
		unlink($obj_self->{_uri_Path});
		}

	return(true);
	}

sub _CleanAgentsList (\@) {
	my $are_list		= shift;

	local $SIG{CLD}		= q{IGNORE};
	local $SIG{CHLD}	= q{IGNORE};

	return(grep { kill(0 => $_->{_pid_Parent}) && ( $_->{_pid_Agent} == $$ || kill(0 => $_->{_pid_Agent}) ) } @{$are_list});
	}

# Integrated lock system
sub TokenLock {
	my $obj_self		= shift;
	my $bol_Init		= true;

	if ( ! -e $obj_self->{_uri_Path} ) {
		my $str_Caller	= (caller(0))[3];
		croak qq{$str_Caller(): Lock file missing\nHave you ever called MainLock() ?\n};
		}

	while ( true ) {
		if ( -e $obj_self->{_uri_Path}
		&& open(my $fh, "<", $obj_self->{_uri_Path}) ) {
			flock($fh, 2);
			my $str_Caller				= (caller(0))[3];

			# Load current data
			$obj_self->{_har_Data}			= retrieve($obj_self->{_uri_Path});

			@{$obj_self->{_har_Data}->{are_Token}}	= _CleanAgentsList(@{$obj_self->{_har_Data}->{are_Token}});

			# If we never got a token, we request one
			if ( $bol_Init
			&& ! first { $_->{_pid_Agent} == $$ } @{$obj_self->{_har_Data}->{are_Token}} ) {
				$bol_Init	= false;
				push(@{$obj_self->{_har_Data}->{are_Token}}, { _pid_Agent => $$, _pid_Parent => $obj_self->{_pid_Parent} });
				}
			elsif ( ! -e $obj_self->{_uri_Path}
			|| ( ! $bol_Init
			&& ! first { $_->{_pid_Parent} == $obj_self->{_pid_Parent} } @{$obj_self->{_har_Data}->{are_Token}} ) ) {
				# Parent exited (and maybe we weren't informed to exit)
				close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};
				exit(120);
				}

			store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

			close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};

			# Check if it's our turn
			if ( $obj_self->{_har_Data}->{are_Token}->[0]->{_pid_Agent} == $$ ) {
				return(true);
				}
			# If it isn't our turn wait
			else {
				Time::HiRes::sleep(0.01);	# Needed to prevent permanent spamming on CPU and FS
				}
			}
		elsif ( ! -e $obj_self->{_uri_Path} ) {
			# Parent exited (and maybe we weren't informed to exit)
			exit(120);
			}
		}
	}

sub TokenUnlock {
	my $obj_self		= shift;
	my $int_RemovedToken	= undef;

	if ( ! -e $obj_self->{_uri_Path} ) {
		my $str_Caller	= (caller(0))[3];
		croak qq{$str_Caller(): Lock file missing\nHave you ever called MainLock() ?\n};
		}

	if ( open(my $fh, "<", $obj_self->{_uri_Path}) ) {
		flock($fh, 2);

		$obj_self->{_har_Data}			= retrieve($obj_self->{_uri_Path});

		@{$obj_self->{_har_Data}->{are_Token}}	= _CleanAgentsList(@{$obj_self->{_har_Data}->{are_Token}});
		$int_RemovedToken			= shift(@{$obj_self->{_har_Data}->{are_Token}});
		store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

		my $str_Caller				= (caller(0))[3];
		if ( $int_RemovedToken->{_pid_Agent} != $$ ) {
			carp qq{$str_Caller(): Removed PID $int_RemovedToken->{_pid_Agent} while running under PID $$ (should be the same)\n};
			}
		close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};
		}
	}

# Allows transporting developers data between processes (custom IPC)
sub SetCustomData {
	my $obj_self		= shift;
	my $ref_Data		= shift;

	if ( ! -e $obj_self->{_uri_Path} ) {
		my $str_Caller	= (caller(0))[3];
		croak qq{$str_Caller(): Lock file missing\nHave you ever called MainLock() ?\n};
		}

	if ( !( ref($ref_Data)
	|| ! defined($ref_Data) ) ) {
		my $str_Caller	= (caller(0))[3];
		croak qq{$str_Caller(): ref_Data=:"$ref_Data" is not a reference nor NULL\n};
		}

	if ( open(my $fh, "<", $obj_self->{_uri_Path}) ) {
		flock($fh, 2);

		$obj_self->{_har_Data}		= retrieve($obj_self->{_uri_Path});

		if ( ref($ref_Data) eq q{ARRAY} ) {
			$obj_self->{_har_Data}->{ref_CustomData}	= [ @{$ref_Data} ];
			}
		elsif ( ref($ref_Data) eq q{HASH} ) {
			$obj_self->{_har_Data}->{ref_CustomData}	= { %{$ref_Data} };
			}
		elsif ( ref($ref_Data) eq q{SCALAR} ) {
			$obj_self->{_har_Data}->{ref_CustomData}	= ${$ref_Data} . "";
			}
		elsif ( ref($ref_Data) eq q{CODE} ) {
			$obj_self->{_har_Data}->{ref_CustomData}	= $ref_Data;
			}
		else {  # Undef undef
			$obj_self->{_har_Data}->{ref_CustomData}	= undef;
			}

		store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

		my $str_Caller	= (caller(0))[3];
		close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};
		}

	return(true);
	}

# Allows transporting developers data between processes (custom IPC)
sub GetCustomData {
	my $obj_self		= shift;

	if ( ! -e $obj_self->{_uri_Path} ) {
		my $str_Caller	= (caller(0))[3];
		croak qq{$str_Caller(): Lock file missing\nHave you ever called MainLock() ?\n};
		}

	try {
		$obj_self->{_har_Data}	= lock_retrieve($obj_self->{_uri_Path});
		}
	catch ($str_Error) {
		carp qq{"$obj_self->{_uri_Path}": Mailformed shared memory file.\n$str_Error\n};
		return(undef);
		}

	return($obj_self->{_har_Data}->{ref_CustomData});
	}

sub _EndProcedure {
	foreach my $obj_self ( @obj_EndSelf ) {
		&DESTROY($obj_self);
		}
	}

1;
