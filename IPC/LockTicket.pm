#!/usr/bin/perl

=begin meta_information

	License:		GPLv3 - see license file or http://www.gnu.org/licenses/gpl.html
	Program-version:	<see below>
	Description:		Libriary for IPC and token based lock mechanism.
	Contact:		Dominik Bernhardt - domasprogrammer@gmail.com or https://github.com/DomAsProgrammer

=end meta_information

=begin License

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

=end License
=cut

=begin Version

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
	False coded bol_multiple corrected.

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

=end Version
=cut

=begin how_to

use IPC::LockTicket;

my $object	= IPC::LockTicket->new(qq{name}, <chmod num>);	# For SPEED:	Creates a shared handle within
								# /dev/shm (allowed symbols: m{^[a-z0-9]+$}i)
								# name like name

my $object	= IPC::LockTicket->new(qq{/absolute/path.file}, <chmod num>)
								# For STORAGE:	Creates a shared handle at the
								# given path (must be a file name)

$bol_succcess	= $object->main_lock(1);			# For MULTIPLE usage: allows calling main_lock()
								# multiple times on same file to allow IPC even
								# if it's not from a fork (applies only on same
								# name or file) i.e. it's not failing on
								# main_lock() if file exists

$bol_succcess	= $object->main_lock();				# Creates shm/lock-file or if existing and
								# MULTIPLE is active for file and new object
								# it implements the PID

$bol_succcess	= $object->token_lock();			# Get a ticket to queue up - blocks until it's
								# our turn

$bol_succcess	= $object->set_custom_data($reference);		# Save any data as reference - be aware this
								# decreases speed and you fastly run out of
								# space

$reference	= $object->get_custom_data();			# Load custom data block

$bol_succcess	= $object->token_unlock();			# We're done and next one's turn is now

$bol_succcess	= $object->main_unlock();			# Removes PID from lock file on MULTIPLE. If
								# no more PIDs are within the lockfile it re-
								# moves the lock file as well.
								# Hint: The user of the library must take
								# care when to main_unlock() e.g. wait until
								# all child processes died.

=end how_to
=cut

=begin variables

	str	string
	 L sql	sql code
	 L cmd	command string
	 L ver	version number
	 L bin	binary data, also base64
	 L hex  hex coded data
	 L pth	path

	int	integer number
	 L cnt	counter
	 L pid	process id number
	 L tme	seconds since period
	 L cnt	counter

	flt	floating point number

	bol	boolean

	ref	reference
	 L rxp	regular expression
	 L are	array reference
	 L tbl	table - ( a hash array with PK as identifier OR an array ) AND hash arrays as values
	 L dsc	file discriptor (type glob)
	 L _sub	anonymous subfunction before Perl v5.26
	 L har	hash array reference
	  L obj	object

=end variables
=cut

##### C L A S S  D E F I N I T I O N #####
package IPC::LockTicket;

##### L I B R I A R I E S #####

use strict;
use warnings;
use Storable qw(store retrieve lock_store lock_retrieve);	# Base for this library
use Time::HiRes;
use feature qw( unicode_strings current_sub fc );
use open qw( :std :encoding(UTF-8) );				# Full UTF-8 support
use utf8;							# Full UTF-8 support
use List::Util qw( first );
### MetaCPAN
use Try;							# Better replacement for eval()
use boolean;							# Boolean type support


##### D E C L A R A T I O N #####
local $ENV{LANG}		= q{en_GB.UTF-8};
local $ENV{LANGUAGE}		= q{en_GB};


##### M E T H O D S #####

sub new {
	my $str_class		= shift;
	my $obj_self	= {
		_str_path			=> shift,	# Path or name for Storable
		_int_permission			=> shift,	# Permissons for the created file
		pid_parent			=> $$,
		_har_data		=> {
			bol_multiple		=> false,	# Allows multiple locks on same file
			are_pids		=> [],		# main_lock() mechanism ; list of parents
			ref_cust_data		=> undef,	# Place to save data for lib user
			are_token		=> [		# Array for FIFO handling
				#{
					# pid_agent	=> PID,
					# pid_parent	=> PID,
					#},
				],
			},
		};

	# If name is not a path or a name with prohibited characters
	if ( $obj_self->{_str_path} && $obj_self->{_str_path} =~ m{^[-_a-z0-9]+$}i ) {
		my $bol_working_found	= false;

		# Find a fitting directory
		test_dir:
		foreach my $str_dir ( qw( /dev/shm /run/shm /run /tmp ) ) {
			if ( -d $str_dir && -w $str_dir ) {
				$obj_self->{_str_path}		= qq{$str_dir/IPC__LockTicket-Shm_$obj_self->{_str_path}};
				$bol_working_found		= true;
				last(test_dir);
				}
			}

		# Stop if no fitting dir was found
		if ( ! $bol_working_found ) {
			my $str_caller	= (caller(0))[0];
			die qq{$str_caller(): Can't find any suitable directory\nIs this a systemd *NIX?\n};
			}
		}

	if ( &_check($obj_self) ) {
		bless($obj_self, $str_class);
		return($obj_self);
		}

	return(undef);
	}

# Similar to main_unlock, but without blocking tokens
sub DESTROY {
	my $obj_self		= shift;

	# Only remove PID / lock file if the requesting process has created it
	if ( -e $obj_self->{_str_path} && grep { $$ == $_ } $obj_self->_get_pids() ) {

		# Obsolete, doing the same as main_unlock() while we already have a function for this purpose
		my @int_pids	= do {
			local $SIG{CLD}		= q{IGNORE};
			local $SIG{CHLD}	= q{IGNORE};

			grep { kill(0 => $_) } grep { $_ != $$ } $obj_self->_get_pids();
			};
		# Get running PIDs from lock file which are not the current process
		# to check if this process is the last one.

		# If there are other processes running
		if ( @int_pids && $obj_self->_multiple_allowed() && open(my $fh, "<", $obj_self->{_str_path}) ) {
			flock($fh, 2);

			$obj_self->{_har_data}	= retrieve($obj_self->{_str_path});

			# Calculate new data - this is needed, because flock() might have delayed the former request
			$obj_self->{_har_data}->{are_pids}	= [ do {
				local $SIG{CLD}			= q{IGNORE};
				local $SIG{CHLD}		= q{IGNORE};

				grep { kill(0 => $_) } grep { $_ != $$ } @{$obj_self->{_har_data}->{are_pids}};
				} ];

			store($obj_self->{_har_data}, $obj_self->{_str_path});

			my $str_caller	= (caller(0))[3];
			close($fh) or die qq{$str_caller(): Unable to close "$obj_self->{_str_path}" properly\n};

			# If we exited as last process we now can delete the file
			if ( ! @{$obj_self->{_har_data}->{are_pids}} ) {
				unlink($obj_self->{_str_path});
				}
			}
		# If we are the last exiting process
		else {
			unlink($obj_self->{_str_path});
			}
		}

	return(true);
	}

sub _check {
	my $obj_self		= shift;
	my $str_errors		= '';

	if ( $obj_self->{_str_path} && -s $obj_self->{_str_path} && open(my $fh, "<", $obj_self->{_str_path}) ) {
		flock($fh, 2);

		# Test if file is readable
		try {
			retrieve($obj_self->{_str_path})
			}
		catch {
			$str_errors	.= qq{"$obj_self->{_str_path}": Mailformed shared memory file\n$@\n};
			}

		my $str_caller	= (caller(0))[3];
		close($fh) or $str_errors .= qq{$str_caller(): Unable to close "$obj_self->{_str_path}" properly\n};
		}
	elsif ( ! defined($obj_self->{_str_path}) ) {
		my $str_caller	= (caller(0))[3];
		$str_errors		.= qq{$str_caller(): Missing argument!\n};
		}
	# If open failes
	elsif ( -e $obj_self->{_str_path} ) {
		my $str_caller	= (caller(0))[3];
		$str_errors		.= qq{$str_caller(): Unable to open "$obj_self->{_str_path}"!\n};
		}

	if ( $obj_self->{_str_path} && -d $obj_self->{_str_path} ) {
		$str_errors	.= qq{"$obj_self->{_str_path}": A folder can't be a share memory file!\n};
		}
	if ( $obj_self->{_str_path} !~ m{^\.?\.?/.+$} ) {
		$str_errors	.= qq{"$obj_self->{_str_path}": is an inadequate path or name!\n};
		}

	# Protect file if not set other wise
	if ( ! defined($obj_self->{_int_permission}) ) {
		$obj_self->{_int_permission}	= 0600;
		}
	elsif ( -e $obj_self->{_str_path} && ! -r $obj_self->{_str_path} ) {
		$str_errors	.= qq{"$obj_self->{_str_path}": No read permission.\n};
		}
	elsif ( -e $obj_self->{_str_path} && ! -w $obj_self->{_str_path} ) {
		$str_errors	.= qq{"$obj_self->{_str_path}": No write permission.\n};
		}

	if ( $str_errors ) {
		die $str_errors;
		}

	return(true);
	}

# Returns an array of integers which represents all registered PIDs of current lock file
sub _get_pids {
	my $obj_self		= shift;

	$obj_self->{_har_data}	= lock_retrieve($obj_self->{_str_path});

	return(@{$obj_self->{_har_data}->{are_pids}});
	}

# Save a array of integer
sub _set_pids {
	my $obj_self		= shift;
	my @int_pids		= @_;

	if ( open(my $fh, "<", $obj_self->{_str_path}) ) {
		flock($fh, 2);

		$obj_self->{_har_data}			= retrieve($obj_self->{_str_path});

		$obj_self->{_har_data}->{are_pids}	= [ @int_pids ];

		store($obj_self->{_har_data}, $obj_self->{_str_path});

		my $str_caller	= (caller(0))[3];
		close($fh) or die qq{$str_caller(): Unable to close "$obj_self->{_str_path}" properly\n};
		}

	return(true);
	}

# Returns boolean value
sub _multiple_allowed {
	my $obj_self		= shift;

	$obj_self->{_har_data}	= lock_retrieve($obj_self->{_str_path});

	return($obj_self->{_har_data}->{bol_multiple});
	}

# Creates the lock file
sub main_lock {
	my $obj_self		= shift;
	my $bol_multiple	= shift;

	# If the file exists
	if ( -e $obj_self->{_str_path} && $obj_self->_check() ) {	# Dies in _check if failed
		# If multiple is allowed we register our PID
		if ( $bol_multiple && $obj_self->_multiple_allowed() ) {
			$obj_self->token_lock();

			my @int_pids	= $obj_self->_get_pids();

			if ( grep { $_ == $$ } @int_pids ) {
				print STDERR qq{WARNING: Same process tried to main_lock() again.\n};
				$obj_self->token_unlock();
				return(false);
				}
			else {
				$obj_self->_set_pids( @int_pids, $$ );
				}

			$obj_self->token_unlock();
			}
		# Or we fail
		else {
			return(false);
			}
		}
	# Create file and write our format
	elsif ( ! -e $obj_self->{_str_path} ) {
		if ( open(my $fh, ">", $obj_self->{_str_path}) ) {
			close($fh);

			chmod($obj_self->{_int_permission}, $obj_self->{_str_path});

			$obj_self->{_har_data}->{bol_multiple}		= ( $bol_multiple ) ? true : false;
			$obj_self->{pid_parent}				= $$;
			push(@{$obj_self->{_har_data}->{are_pids}}, $$);

			lock_store($obj_self->{_har_data}, $obj_self->{_str_path});
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
sub main_unlock {
	my $obj_self		= shift;

	if ( ! -e $obj_self->{_str_path} ) {
		my $str_caller	= (caller(0))[3];
		die qq{$str_caller(): Lock file missing\nHave you ever called main_lock() ?\n};
		}

	if ( $obj_self->_multiple_allowed() ) {
		my @int_pids	= ();

		$obj_self->token_lock();

		@int_pids	= do {
			local $SIG{CLD}		= q{IGNORE};
			local $SIG{CHLD}	= q{IGNORE};

			grep { kill(0 => $_) } grep { $_ != $$ } $obj_self->_get_pids();
			};

		if ( @int_pids ) {
			$obj_self->_set_pids(@int_pids);
			$obj_self->token_unlock();
			}
		else {
			unlink($obj_self->{_str_path});
			}

		}
	else {
		unlink($obj_self->{_str_path});
		}

	return(true);
	}

sub _clean_agents_list (\@) {
	my $are_list		= shift;

	local $SIG{CLD}		= q{IGNORE};
	local $SIG{CHLD}	= q{IGNORE};

	return(grep { kill(0 => $_->{pid_parent}) && ( $_->{pid_agent} == $$ || kill(0 => $_->{pid_agent}) ) } @{$are_list});
	}

# Integrated lock system
sub token_lock {
	my $obj_self		= shift;
	my $bol_init		= true;

	if ( ! -e $obj_self->{_str_path} ) {
		my $str_caller	= (caller(0))[3];
		die qq{$str_caller(): Lock file missing\nHave you ever called main_lock() ?\n};
		}

	while ( true ) {
		if ( -e $obj_self->{_str_path} && open(my $fh, "<", $obj_self->{_str_path}) ) {
			flock($fh, 2);
			my $str_caller				= (caller(0))[3];

			# Load current data
			$obj_self->{_har_data}			= retrieve($obj_self->{_str_path});

			@{$obj_self->{_har_data}->{are_token}}	= _clean_agents_list(@{$obj_self->{_har_data}->{are_token}});

			# If we never got a token, we request one
			if ( $bol_init && ! first { $_->{pid_agent} == $$ } @{$obj_self->{_har_data}->{are_token}} ) {
				$bol_init	= false;
				push(@{$obj_self->{_har_data}->{are_token}}, { pid_agent => $$, pid_parent => $obj_self->{pid_parent} });
				}
			elsif ( ! -e $obj_self->{_str_path} || ( ! $bol_init && ! first { $_->{pid_parent} == $obj_self->{pid_parent} } @{$obj_self->{_har_data}->{are_token}} ) ) {
				# Parent exited (and maybe we weren't informed to exit)
				close($fh) or die qq{$str_caller(): Unable to close "$obj_self->{_str_path}" properly\n};
				exit(120);
				}

			store($obj_self->{_har_data}, $obj_self->{_str_path});

			close($fh) or die qq{$str_caller(): Unable to close "$obj_self->{_str_path}" properly\n};

			# Check if it's our turn
			if ( $obj_self->{_har_data}->{are_token}->[0]->{pid_agent} == $$ ) {
				return(true);
				}
			# If it isn't our turn wait
			else {
				Time::HiRes::sleep(0.01);	# Needed to prevent permanent spamming on CPU and FS
				}
			}
		elsif ( ! -e $obj_self->{_str_path} ) {
			# Parent exited (and maybe we weren't informed to exit)
			exit(120);
			}
		}
	}

sub token_unlock {
	my $obj_self		= shift;
	my $int_removed		= undef;

	if ( ! -e $obj_self->{_str_path} ) {
		my $str_caller	= (caller(0))[3];
		die qq{$str_caller(): Lock file missing\nHave you ever called main_lock() ?\n};
		}

	if ( open(my $fh, "<", $obj_self->{_str_path}) ) {
		flock($fh, 2);

		$obj_self->{_har_data}			= retrieve($obj_self->{_str_path});

		@{$obj_self->{_har_data}->{are_token}}	= _clean_agents_list(@{$obj_self->{_har_data}->{are_token}});
		$int_removed				= shift(@{$obj_self->{_har_data}->{are_token}});
		store($obj_self->{_har_data}, $obj_self->{_str_path});

		my $str_caller				= (caller(0))[3];
		if ( $int_removed->{pid_agent} != $$ ) {
			warn qq{$str_caller(): Removed PID $int_removed->{pid_agent} while running under PID $$ (should be the same)\n};
			}
		close($fh) or die qq{$str_caller(): Unable to close "$obj_self->{_str_path}" properly\n};
		}
	}

# Allows transporting developers data between processes (custom IPC)
sub set_custom_data {
	my $obj_self		= shift;
	my $ref_data		= shift;

	if ( ! -e $obj_self->{_str_path} ) {
		my $str_caller	= (caller(0))[3];
		die qq{$str_caller(): Lock file missing\nHave you ever called main_lock() ?\n};
		}

	if ( !( ref($ref_data) || ! defined($ref_data) ) ) {
		my $str_caller	= (caller(0))[3];
		die qq{$str_caller(): ref_data=:"$ref_data" is not a reference nor NULL\n};
		}

	if ( open(my $fh, "<", $obj_self->{_str_path}) ) {
		flock($fh, 2);

		$obj_self->{_har_data}		= retrieve($obj_self->{_str_path});

		if ( ref($ref_data) eq q{ARRAY} ) {
			$obj_self->{_har_data}->{ref_cust_data}	= [ @{$ref_data} ];
			}
		elsif ( ref($ref_data) eq q{HASH} ) {
			$obj_self->{_har_data}->{ref_cust_data}	= { %{$ref_data} };
			}
		elsif ( ref($ref_data) eq q{SCALAR} ) {
			$obj_self->{_har_data}->{ref_cust_data}	= ${$ref_data} . "";
			}
		elsif ( ref($ref_data) eq q{CODE} ) {
			$obj_self->{_har_data}->{ref_cust_data}	= $ref_data;
			}
		else {  # Undef undef
			$obj_self->{_har_data}->{ref_cust_data}	= undef;
			}

		store($obj_self->{_har_data}, $obj_self->{_str_path});

		my $str_caller	= (caller(0))[3];
		close($fh) or die qq{$str_caller(): Unable to close "$obj_self->{_str_path}" properly\n};
		}

	return(true);
	}

# Allows transporting developers data between processes (custom IPC)
sub get_custom_data {
	my $obj_self		= shift;

	if ( ! -e $obj_self->{_str_path} ) {
		my $str_caller	= (caller(0))[3];
		die qq{$str_caller(): Lock file missing\nHave you ever called main_lock() ?\n};
		}

	$obj_self->{_har_data}	= lock_retrieve($obj_self->{_str_path});

	return($obj_self->{_har_data}->{ref_cust_data});
	}

1;
