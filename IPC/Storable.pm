#!/usr/bin/perl

package IPC::Storable;

use strict;
use warnings;
use Storable qw(store retrieve lock_store lock_retrieve);
use Time::HiRes;

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

=begin Meta_data

	v0.1 Beta
	I often had problems installing IPC::Sharable on different platforms.
	So I built this library runable with only (Enterprise Linux) default
	Perl installation.

	v0.2 Beta
	Missing control added

	v0.2.1 Beta
	Extended how_to

	v1
	Bugfixes and release

	v1.1
	Now protects content of the file, only accessible by owner.

=end Meta_data
=cut

=begin how_to

my $object	= IPC::Storable->new(qq{name});			# For SPEED:	Creates a shared handle within
								# /dev/shm (allowed symbols: m{^[a-z0-9]+$}i)
								# name like name

my $object	= IPC::Storable->new(qq{/absolute/path.file})	# For STORAGE:	Creates a shared handle at the
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

sub new {
	my $str_class		= shift;
	my @mxd_attributes	= @_;
	my $obj_self		= {};

	if ( ref($str_class) ) {	# Clone
		$obj_self		= $str_class;
		}
	else {
		$obj_self	= {
			_str_path	=> shift(@mxd_attributes),
			_har_data	=> {
				bol_multiple		=> 0,
				are_pids		=> [],		# main_lock() mechanism
				ref_cust_data		=> undef,
				int_token_next		=> 0,		# token_lock() mechanism
				int_token_current	=> 0,		# token_lock() mechanism
				},
			};
		}

	if ( $obj_self->{_str_path} && $obj_self->{_str_path} =~ m{^[a-z0-9]+$}i ) {
		my $bol_working_found	= 0;

		test_dir:
		foreach my $str_dir ( qw( /dev/shm /run /tmp ) ) {
			if ( -d $str_dir && -w $str_dir ) {
				$obj_self->{_str_path}		= qq{$str_dir/IPC__Storable-Shm_$obj_self->{_str_path}};
				$bol_working_found		= 1;
				last(test_dir);
				}
			}

		if ( ! $bol_working_found ) {
			my($str_caller)	= caller(0);
			die qq{$str_caller : Can't find any suitable directory\nIs this a systemd *NIX?\n};
			}
		}
	elsif ( $obj_self->{_str_path} && -d $obj_self->{_str_path} ) {
		die qq{"$obj_self->{_str_path}": A folder can't be a share memory file!\n};
		}

	if ( &_check($obj_self) ) {
		bless($obj_self, $str_class);
		return($obj_self);
		}

	return(undef);
	}

sub _check {
	my $obj_self		= shift;

	if ( $obj_self->{_str_path} && -s $obj_self->{_str_path} && open(my $fh, "<", $obj_self->{_str_path}) ) {
		flock($fh, 2);

		eval { retrieve($obj_self->{_str_path}) };

		my(undef, undef, undef, $str_caller)	= caller(0);
		close($fh) or die qq{$str_caller : Unable to close "$obj_self->{_str_path}" properly\n};

		if ( $@ ) {
			die qq{"$obj_self->{_str_path}": Mailformed shared memory file\n$@\n};
			}
		}
	elsif ( ! defined($obj_self->{_str_path}) ) {
		my(undef, undef, undef, $str_caller)	= caller(0);
		print STDERR qq{$str_caller : Missing argument!\n};
		return(0);
		}

	return(1);
	}

sub _get_pids {
	my $obj_self		= shift;

	$obj_self->{_har_data}	= lock_retrieve($obj_self->{_str_path});

	return(@{$obj_self->{_har_data}->{are_pids}});
	}

sub _set_pids {
	my $obj_self		= shift;
	my @int_pids		= @_;

	if ( open(my $fh, "<", $obj_self->{_str_path}) ) {
		flock($fh, 2);

		$obj_self->{_har_data}			= retrieve($obj_self->{_str_path});

		$obj_self->{_har_data}->{are_pids}	= [ @int_pids ];

		store($obj_self->{_har_data}, $obj_self->{_str_path});

		my(undef, undef, undef, $str_caller)		= caller(0);
		close($fh) or die qq{$str_caller : Unable to close "$obj_self->{_str_path}" properly\n};
		}

	return(1);
	}

sub _multiple_allowed {
	my $obj_self		= shift;

	$obj_self->{_har_data}	= lock_retrieve($obj_self->{_str_path});

	return($obj_self->{_har_data}->{bol_multiple});
	}

sub main_lock {
	my $obj_self		= shift;
	my $bol_multiple	= shift;

	if ( -e $obj_self->{_str_path} && $obj_self->_check() ) {

		if ( $bol_multiple && $obj_self->_multiple_allowed() ) {
			$obj_self->token_lock();
			my @int_pids	= $obj_self->_get_pids();

			if ( grep { $_ == $$ } @int_pids ) {
				print STDERR qq{WARNING: Same process tried to main_lock() again.\n};
				$obj_self->token_unlock();
				return(0);
				}
			else {
				$obj_self->_set_pids( @int_pids, $$ );
				}

			$obj_self->token_unlock();
			}
		else {
			my(undef, undef, undef, $str_caller)	= caller(0);
			print STDERR qq{$str_caller : Already locked\n};

			return(0);
			}
		}
	else {
		if ( open(my $fh, ">", $obj_self->{_str_path}) ) {
			close($fh);

			chmod(0600, $obj_self->{_str_path});

			$obj_self->{_har_data}->{bol_multiple}		= 1;
			push(@{$obj_self->{_har_data}->{are_pids}}, $$);

			lock_store($obj_self->{_har_data}, $obj_self->{_str_path});
			}
		}

	return(1);
	}

sub main_unlock {
	my $obj_self		= shift;

	if ( $obj_self->_multiple_allowed() ) {
		my @int_pids	= ();

		$obj_self->token_lock();

		@int_pids	= grep { local $SIG{CLD} = q{IGNORE}; local $SIG{CHLD} = q{IGNORE}; kill(0 => $_) } grep { $_ != $$ } $obj_self->_get_pids();

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

	return(1);
	}

sub token_lock {
	my $obj_self		= shift;
	my $int_token		= undef;

	if ( ! -e $obj_self->{_str_path} ) {
		die qq{Lock file missing\nHave you ever called main_lock() ?\n};
		}

	while ( 1 ) {
		if ( open(my $fh, "<", $obj_self->{_str_path}) ) {
			flock($fh, 2);

			$obj_self->{_har_data}		= retrieve($obj_self->{_str_path});

			if ( ! defined($int_token) ) {
				$int_token		= $obj_self->{_har_data}->{int_token_next}++;
				store($obj_self->{_har_data}, $obj_self->{_str_path});
				}

			my(undef, undef, undef, $str_caller)	= caller(0);
			close($fh) or die qq{$str_caller : Unable to close "$obj_self->{_str_path}" properly\n};

			if ( $obj_self->{_har_data}->{int_token_current} >= $int_token ) {
				return(1);
				}
			else {
				Time::HiRes::sleep(0.2);
				}
			}
		}
	}

sub token_unlock {
	my $obj_self		= shift;

	if ( open(my $fh, "<", $obj_self->{_str_path}) ) {
		flock($fh, 2);

		$obj_self->{_har_data}		= retrieve($obj_self->{_str_path});

		$obj_self->{_har_data}->{int_token_current}++;
		store($obj_self->{_har_data}, $obj_self->{_str_path});

		my(undef, undef, undef, $str_caller)	= caller(0);
		close($fh) or die qq{$str_caller : Unable to close "$obj_self->{_str_path}" properly\n};
		}
	}

sub set_custom_data {
	my $obj_self		= shift;
	my $ref_data		= shift;

	if ( !( ref($ref_data) || ! defined($ref_data) ) ) {
		my(undef, undef, undef, $str_caller)	= caller(0);
		die qq{$str_caller : ref_data=:"$ref_data" is not a reference nor NULL\n};
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

		my(undef, undef, undef, $str_caller)	= caller(0);
		close($fh) or die qq{$str_caller : Unable to close "$obj_self->{_str_path}" properly\n};
		}

	return(1);
	}

sub get_custom_data {
	my $obj_self		= shift;

	$obj_self->{_har_data}	= lock_retrieve($obj_self->{_str_path});

	return($obj_self->{_har_data}->{ref_cust_data});
	}

1;
