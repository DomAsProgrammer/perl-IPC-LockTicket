#!/usr/bin/env perl

=begin meta_information

=encoding utf8

	License:		BSD-2-Clause
	Program-version:	<see below>
	Description:		Libriary for IPC and token based
				lock mechanism.
	Contact:		Dominik Bernhardt - domasprogrammer@gmail.com or https://github.com/DomAsProgrammer

=end meta_information

=begin license

	Transport data between applications (IPC) via Storable library
	Copyright © 2025 Dominik Bernhardt

	Redistribution and use in source and binary
	forms, with or without modification, are permitted
	provided that the following conditions are met:

	1. Redistributions of source code must retain the
	above copyright notice, this list of conditions and the
	following disclaimer.

	2. Redistributions in binary form must reproduce
	the above copyright notice, this list of conditions and
	the following disclaimer in the documentation and/or
	other materials provided with the distribution.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT
	HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR
	IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
	PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
	COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
	PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
	OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
	DAMAGE.

=end license

=begin version_history

	v0.1 Beta
	I often had problems installing IPC::Shareable on dif-
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

	v2.00
	Significant changes!
	Renamed
	Now working with a FIFO array, but nothing should change
	for the lib user.

	v2.01
	Some bugfixes.

	v2.02
	Implemented Carp and Exporter.
	Declared version.

	v2.03
	Used END block to properly end the program.

	v2.04
	Switched to Perl v5.40.0, removed Try and replaced by
	feature q{try}

	v2.05
	Perl v5.40.0 also supports boolean values nativly.
	Removed boolean and used builtin's true and false.

	v2.06
	Bugfix of lock_retrieve() on scrambled files.

	v2.07
	Detection and warning of orphan lock files.

	v2.08
	New terminology
	Compatibility layer

	v2.09
	Removed compatibility layer

	v2.10
	New dependency for FreeBSD: /run as tmpfs in testing
	Full fledged pod.

	v2.10.01
	Bugfix: Dynamic lock file target mode is now case
	sensetive agian.

	v2.11
	Bugfixes

	v2.12
	Cares about lock file's permissions in detail.

	v2.13
	Better handling if TokenUnlock() was called if TokenLock() was never called before.
	Improved manual.

=end version_history

=begin comment

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

=end comment

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
	 L oct  octal number
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

=head1 NAME

IPC::LockTicket - Use Storable library to IPC token to prevent parallel access to any resources. Including your custom data to transfer asynchronously.

=head1 SYNOPSIS

 use strict;
 use warnings;
 use IPC::LockTicket;

 my $object	= IPC::LockTicket->New(@options);

 my $object	= IPC::LockTicket->New(qq{name}, 0666);
   # ...or
 my $object	= IPC::LockTicket->New(qq{/absolute/path.file}, 0600)

 # This fails if the IPC file exists already
 $bol_succcess	= $object->MainLock();

 $bol_succcess	= $object->SetCustomData($reference);

 # fork() and do within Child1:
 # Child1 represents best practice.

 $bol_succcess	= $object->TokenLock(); # Blocks unless lock is aquired.

 $reference	= $object->GetCustomData();
 # Do something with $reference
 $bol_succcess	= $object->SetCustomData($reference);

 $bol_succcess	= $object->TokenUnlock(); # Other children can only use the
   # updated version, but were blocked until this point. Best practice is
   # keeping the Time between TokenLock() and TokenUnlock() as short as
   # possible.

 # Within a different Child2:
 $reference	= $object->GetCustomData(); # This is safe, but right after this
   # call the data might change, because it is not controlled through any mechanism.
   # This is useful if one just needs to get the current state, but doesn't rely on
   # persistence.

 # Within another different ChildN:
 $bol_succcess	= $object->SetCustomData($reference); # This is safe, too, but
   # it might lead to data loss through overwriting existing data.

 # At the end the parent does:
 $bol_succcess	= $object->MainUnlock();

 # Hand over a true value if multiple parents shall use the same IPC file:
 $bol_succcess	= $object->MainLock(1);

=head1 DESCRIPTION

IPC::LockTicket allows one to get a simple token/ticket locking mechanism, like C<flock()> does, but FIFO sorted.
It also makes it easy to transport small amount of data between processes.

The data you want to transfer must be saved as an anonymous reference, and returns as such.

The data is not transferred in real time, but only on request. While you might store whole objects if you need the most recent of them, lock the store, load it, change it and store it again before you unlock it again.

In theory, you can store as much data as your disk can hold, but be aware: this will slow down the lock mechanism. Use multiple files in this case: One only holds data (full path), the other is just for locking (dynamic path).

=cut

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
use English qw( -no_match_vars );

BEGIN {	# Good practice of Exporter but we don't have anything to export
	our @EXPORT_OK	= ();
	our $VERSION	= q{2.13};
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
my @uri_LinuxDirs	= qw( /dev/shm /run/shm /run /tmp );
my @uri_BSDirs		= qw( /run /var/spool/lock /tmp );
my @uri_Accord		= ( fc($^O) eq fc(q(FreeBSD)) ) ? @uri_BSDirs : @uri_LinuxDirs;

my $rxp_TempFS		= qr{^(?:tmp|ram)fs$}i;
my $rxp_OptionSplit	= qr{,\s*};
my $rxp_MountLinux	= qr{^
	([^\s]+)	# Device	1
	\s+on\s+
	([^\s]+)/*	# Mount point	2
	\s+type\s+
	([^\s]+)	# File system	3
	\s*\(		# literal braket
	(.+)		# Options	4
	\s*\)\s*	# literal braket
	$}xx;
my $rxp_MountBSD	= qr{^
	([^\s]+)	# Device	1
	\s+on\s+
	([^\s]+)/*	# Mount point	2
	\s*\(		# literal braket
	([^\s,]+)	# File system	3
	(?:, ?)?
	(.+)?		# Options	4
	\s*\)\s*	# literal braket
	$}xx;
my $rxp_Accord		= ( fc($^O) eq fc(q(FreeBSD)) ) ? $rxp_MountBSD : $rxp_MountLinux;
my $rxp_GoodPath	= qr{^[-_a-z0-9]{1,218}$}i;
my $rxp_FullPath	= qr{^\.?\.?/.+$};
my $rxp_Whitespaces	= qr{\s+};
my $rxp_OctalNum	= qr{^\o{4}$};

##### M E T H O D S #####

=head1 IPC::LockTicket Class METHODS

=head3 C<New>

 my $object	= IPC::LockTicket->new($str_Name, $oct_Permission) or die;

Creates a new IPC::LockTicket object, which is returned. Returns C<undef> on failure. Expects one or two arguments. First the name, optionally secondly the permission as an octal number.

=over 2

=item name

String just matching C<m{^[-_a-z0-9]+$}i> for dynamic naming or a full path to a file.
Mandatory.

=item permission

Access rights that the lock file will have.
For example, if just a collision protection shall be implemented, it might be the best to set it to 0666, so collisions can be prevented over the whole system for every user.
Expects an octal number, like L<chmod(1)>.
Defaults to C<0600>.

=back

=cut

sub new { goto &New; } # Keep regular naming for Perl objects
sub New {
	my $str_Class				= shift;
	my $obj_self	= {
		_uri_Path			=> shift,	# Path or name for Storable
		_oct_Permission			=> shift,	# Permissons for the created file
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
	&& $obj_self->{_uri_Path} =~ m{$rxp_GoodPath}i ) {
		my $bol_WorkingDirFound	= false;
		my $are_Mounts		= _GetMounts();

		# Find a fitting directory
		lop_TestDir:
		foreach my $str_Dir ( @uri_Accord ) {
			if ( -d $str_Dir
			&& -w $str_Dir
			&& grep { $str_Dir eq $_->{uri_MountPoint} && $_->{str_FileSystem} =~ m{$rxp_TempFS} } @{$are_Mounts} ) {
				$obj_self->{_uri_Path}		= qq{$str_Dir/IPC__LockTicket-$obj_self->{_uri_Path}.shm};
				$bol_WorkingDirFound		= true;
				last(lop_TestDir);
				}
			}

		if ( ! $bol_WorkingDirFound ) {
			# Try even harder
			lop_TestDirAgain:
			foreach my $str_Dir ( @uri_Accord ) {
				if ( -d $str_Dir
				&& -w $str_Dir ) {
					$obj_self->{_uri_Path}	= qq{$str_Dir/IPC__LockTicket-$obj_self->{_uri_Path}.shm};
					$bol_WorkingDirFound	= true;
					last(lop_TestDirAgain);
					}
				}
			}

		# Stop if no fitting dir was found
		if ( ! $bol_WorkingDirFound ) {
			my $str_Caller	= (caller(0))[0];
			croak qq{$str_Caller(): Can't find any suitable directory\n}
				. qq{Expected any of these to exist:\n}
				. qq{@uri_Accord\n};
			}

		}

	if ( &_Check($obj_self) ) {
		bless($obj_self, $str_Class);
		push(@obj_EndSelf, $obj_self);
		return($obj_self);
		}

	return(undef);
	}

=head3 C<DESTROY>

 my $bol_Success	= $object->DESTROY();

Destroys the object so it removes lock files or PIDs from lock files. Automatically called on C<undef($object)>, C<die>, C<exit>, and when C<$object> leaves the scope.

B<Not> called if another module C<croak()>s or if the application fails through an exception at runtime.

Z<>

If not called, the next C<MainLock()> will clear the orphan file, but it is not clear that the content was written properly. If the file is empty or cannot be read, it will not be cleared, but C<MainLock()> will fail. See L<C<MainLock>> for further details.

=cut

# Similar to MainUnlock, but without blocking tokens
sub DESTROY {
	my $obj_self		= shift;

	# Test if file is readable
	try {
		lock_retrieve($obj_self->{_uri_Path})
		}
	catch ($str_Error) {
		# Not readable
		return(true);
		}

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
			$obj_self->{_har_Data}{are_PIDs}	= [ do {
				local $SIG{CLD}			= q{IGNORE};
				local $SIG{CHLD}		= q{IGNORE};

				grep { kill(0 => $_) } grep { $_ != $$ } @{$obj_self->{_har_Data}{are_PIDs}};
				} ];

			store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

			my $str_Caller	= (caller(0))[3];
			close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};

			# If we exited as last process we now can delete the file
			if ( ! @{$obj_self->{_har_Data}{are_PIDs}} ) {
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

sub _GetMounts {
	my @str_Mounts	= qx(mount);
	my @har_Mounts	= (
		# uri_Device		=> < URI Path to device >,
		# uri_MountPoint	=> < URI Path to dir >,
		# str_FileSystem	=> < STR like ext4, autofs, tmpfs, etc. >,
		# are_Options		=> [ ARE of split() ],
		);

	foreach my $str_Line ( @str_Mounts ) {
		chomp($str_Line);

		if ( $str_Line =~ m($rxp_Accord) ) {
			push(@har_Mounts, {
				uri_Device	=> $1,
				uri_MountPoint	=> $2,
				str_FileSystem	=> $3,
				are_Options	=> [
					( $4 ) ? split(m($rxp_OptionSplit), $4) : ()
					],
				});
			}
		}

	@har_Mounts	= sort { $b->{uri_MountPoint} cmp $a->{uri_MountPoint} } @har_Mounts;

	return(\@har_Mounts);
	}

sub _Check {
	my $obj_self		= shift;
	my $str_Errors		= '';

	if ( $obj_self->{_uri_Path}
	&& -s $obj_self->{_uri_Path}
	&& open(my $fh, '<', $obj_self->{_uri_Path}) ) {
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
	if ( $obj_self->{_uri_Path} !~ m{$rxp_FullPath} ) {
		$str_Errors	.= qq{"$obj_self->{_uri_Path}": is an inadequate path or name!\n};
		}

	# Protect file if not set other wise
	if ( defined($obj_self->{_oct_Permission})
	&& length(qq{$obj_self->{_oct_Permission}}) > 4 ) {
		$str_Errors	.= sprintf(qq{"%04o": Invalid permission. Must be a octal number of four or NULL.\n}, $obj_self->{_oct_Permission});
		}
	elsif ( ! defined($obj_self->{_oct_Permission}) ) {
		$obj_self->{_oct_Permission}	= 0600;
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

	# What if permissions differ??
	if ( -e $obj_self->{_uri_Path} ) {
		my %mxd_FileStat	= ();
		my @str_Parts		= qw(o g u ts);
		my $str_Caller		= (caller(0))[3];
		my %int_FilePerms	= ();	# user:users 0600
		my @int_FileGrpsMbrs	= ();
		my %int_ObjPerms	= ();	# root:root 0600
		my $str_EUName		= (getpwuid($EUID))[0];
		my @int_ObjGrps		= ( (getpwuid($EUID))[3] );
		my $cnt_Position	= 0;
		@mxd_FileStat{qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks)} =
			stat($obj_self->{_uri_Path});
		%int_FilePerms		=
			map { $str_Parts[$cnt_Position++] => $_ } #( $_ % 2 ) ? $_ - 1 : $_ }		# Execution bit is not required
			reverse(split('', sprintf(q{%04o}, $mxd_FileStat{mode} & 07777)));
		$cnt_Position		= 0;
		%int_ObjPerms		=
			map { $str_Parts[$cnt_Position++] => $_ } #( $_ % 2 ) ? $_ - 1 : $_ }		# Execution bit is not required
			reverse(split('', sprintf(q{%04o}, $obj_self->{_oct_Permission})));
		@int_FileGrpsMbrs	=		# Group's members
			map { (getpwnam($_))[2] }	# UID
			grep { defined && $_ ne '' }
			split(m{$rxp_Whitespaces}, (getgrgid($mxd_FileStat{gid}))[3]);
		push(@int_FileGrpsMbrs, 0);	# Root is part of any group

		# If file owner's group is same as the file's group we need to add the user's name to the File Group Members list, in case it's the user's main group, which won't be shown by getent groups
		while ( my(undef, undef, $int_UID, $int_GID) = getpwent() ) {

			# Users' default groups
			if ( $int_GID == $mxd_FileStat{gid} ) {	
				push(@int_FileGrpsMbrs, $int_UID);
				}
			}

		while ( my(undef, undef, $int_GID, $str_Members) = getgrent() ) {

			# We need to know all real groups
			if ( grep { $str_EUName eq $_ } split(m{$rxp_Whitespaces}, $str_Members) ) {
				push(@int_ObjGrps, $int_GID);
				}
			}

		if ( $int_FilePerms{o} > $int_ObjPerms{o}	# General rights are to high
		|| $int_FilePerms{g} > $int_ObjPerms{g}		# General rights are to high

		# File is not owned by user's real groups
		||( !( grep { $mxd_FileStat{gid} == $_ } @int_ObjGrps )
		&& $int_FilePerms{g} > $int_ObjPerms{o} )	# Foreign group has more rights as wanted for other users


		# File is not owned effective user
		||($mxd_FileStat{uid} != $EUID
		&& (

		## File owner is part of file owning group -> access can happen through group
		#(grep { $mxd_FileStat{uid} == $_ } @int_FileGrpsMbrs	
		#&& $int_FilePerms{g} > $int_ObjPerms{o} )
		#
		## File owner is not part of file owning group -> access happens only through owner
		#||( !( grep { $mxd_FileStat{uid} == $_ } @int_FileGrpsMbrs )
		( !( grep { $mxd_FileStat{uid} == $_ } @int_FileGrpsMbrs )
		&& $int_FilePerms{u} > $int_ObjPerms{o} )

		) ) ) {
			$str_Errors	.= qq{Existing file "$obj_self->{_uri_Path}" has douptful permissions.\n};

			}
		}

	if ( $str_Errors ) {
		croak $str_Errors;	# die
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

	return(@{$obj_self->{_har_Data}{are_PIDs}});
	}

# Save a array of integer
sub _SetPIDs {
	my $obj_self		= shift;
	my @int_PIDs		= @_;

	if ( open(my $fh, "<", $obj_self->{_uri_Path}) ) {
		flock($fh, 2);

		$obj_self->{_har_Data}			= retrieve($obj_self->{_uri_Path});

		$obj_self->{_har_Data}{are_PIDs}	= [ @int_PIDs ];

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

	return($obj_self->{_har_Data}{bol_AllowMultiple});
	}

=head3 C<MainLock>

 my $bol_Success	= $object->MainLock();
 my $bol_Success	= $object->MainLock(1);

Checks if a lock file exists and creates it if not. Fails if file exists and process stored within is alive.
If a C<true> value is supplied, locking is non-exclusive but shared. If the file exists and was also created non-exclusively, locking is successful. This way the lock file is shared with several processes, requesting non-exclusive mode.
If C<false> is returned from C<MainLock> no lock file was created/claimed.
Meaning:

 ____________________________________________________________________________________________________________________________________
 | Call mode        | MainLock() | MainLock() | MainLock() | MainLock()   | MainLock(1) | MainLock(1) | MainLock(1)  | MainLock(1)  |
 | Lock file        | empty*     | shared     | exclusive  | non-existent | empty*      | shared      | exclusive    | non-existent |
 | MainLock returns | false      | false      | false      | true         | false       | true        | false        | true         |
 ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

*= empty or any other non-Storable data.

=cut

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

			chmod($obj_self->{_oct_Permission}, $obj_self->{_uri_Path});

			$obj_self->{_har_Data}{bol_AllowMultiple}		= ( $bol_MultipleAllowed ) ? true : false;
			$obj_self->{_pid_Parent}				= $$;
			push(@{$obj_self->{_har_Data}{are_PIDs}}, $$);

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

=head3 C<MainUnlock>

 $object->MainUnlock();

Removes lock. The lock file is deleted if this is the last process accessing it.
Returns only a true value.

If it is a shared lock and not the last process accessing it, only the PID entries are removed from the lock file.

=cut

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
	my %bol_TestedParent	= ();

	local $SIG{CLD}		= q{IGNORE};
	local $SIG{CHLD}	= q{IGNORE};

	#			if parent was not tested yet		test if alive,			but we don't test ourself,	but any other agent
	return(grep { ( $bol_TestedParent{$_->{_pid_Parent}}++ || kill(0 => $_->{_pid_Parent}) ) && ( $_->{_pid_Agent} == $$ || kill(0 => $_->{_pid_Agent}) ) } @{$are_list});
	}

=head3 C<TokenLock>

 $object->TokenLock();

Can only be called after C<MainLock> and before C<MainUnlock> otherwise C<die>s.
Requests exclusive lock, i.e., any C<TokenLock> is blocking until C<TokenUnlock> was called, or the locking process is dead. Process checks are done to prevent infinite locks through broken children or parents, but this is not proper usage. Don't just C<exit>, but call C<TokenUnlock> and C<MainUnlock> in appropriate sequence before ending processes!
Returns a true value or blocks.

=cut

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

			@{$obj_self->{_har_Data}{are_Token}}	= _CleanAgentsList(@{$obj_self->{_har_Data}{are_Token}});

			# If we never got a token, we request one
			if ( $bol_Init
			&& ! first { $_->{_pid_Agent} == $$ } @{$obj_self->{_har_Data}{are_Token}} ) {
				$bol_Init	= false;
				push(@{$obj_self->{_har_Data}{are_Token}}, { _pid_Agent => $$, _pid_Parent => $obj_self->{_pid_Parent} });
				}
			# Die if something strange happened
			elsif ( ! -e $obj_self->{_uri_Path}
			|| ( ! $bol_Init
			&& ! first { $_->{_pid_Parent} == $obj_self->{_pid_Parent} } @{$obj_self->{_har_Data}{are_Token}} ) ) {
				# Parent exited (and maybe we weren't informed to exit)
				close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};
				exit(120);
				}

			store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

			close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};

			# Check if it's our turn
			if ( $obj_self->{_har_Data}{are_Token}[0]{_pid_Agent} == $$ ) {
				return(true);
				}
			# Wait if it isn't our turn yet
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

=head3 C<TokenUnlock>

 $object->TokenUnlock();

Can only be called after C<MainLock> and before C<MainUnlock> otherwise C<die>s.
Removes the token from the lock file so any other request of C<TokenLock> can be satisfied.
Returns false if unlock is done while not holding the lock.
Otherwise, it returns true.

=cut

sub TokenUnlock {
	my $obj_self		= shift;
	my $bol_Success		= true;
	my $str_Caller		= (caller(0))[3];

	if ( ! -e $obj_self->{_uri_Path} ) {
		croak qq{$str_Caller(): Lock file missing\nHave you ever called MainLock() ?\n};
		}

	if ( open(my $fh, "<", $obj_self->{_uri_Path}) ) {
		flock($fh, 2);

		$obj_self->{_har_Data}			= retrieve($obj_self->{_uri_Path});

		if ( $obj_self->{_har_Data}{are_Token}[0]{_pid_Agent} != $$ ) {
			carp qq{Lock is on PID $obj_self->{_har_Data}{are_Token}[0]{_pid_Agent}, but PID $$ tries to unlock. Nothing done.\n};

			$bol_Success	= false;
			}

		@{$obj_self->{_har_Data}{are_Token}}	= grep { $_->{_pid_Agent} != $$ }	# Remove ourself from list, either where we are
			_CleanAgentsList(@{$obj_self->{_har_Data}{are_Token}});		# Regular clean up

		store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

		close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};
		}
	else {
		# Open failed

		$bol_Success	= false;
		}

	return($bol_Success);
	}

=head3 C<SetCustomData>

 $object->TokenLock();
 $object->SetCustomData($reference);
 $object->TokenUnlock();

Writes a custom data reference in a reserved area. See L<CAVEATS> and L<GOOD PRACTICE> for further details.
Should be preceded by C<TokenLock()> and followed by C<TokenUnlock()>.
Returns only a true value or C<die>s.

=cut

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
			$obj_self->{_har_Data}{ref_CustomData}	= [ @{$ref_Data} ];
			}
		elsif ( ref($ref_Data) eq q{HASH} ) {
			$obj_self->{_har_Data}{ref_CustomData}	= { %{$ref_Data} };
			}
		elsif ( ref($ref_Data) eq q{SCALAR} ) {
			$obj_self->{_har_Data}{ref_CustomData}	= ${$ref_Data} . "";
			}
		elsif ( ref($ref_Data) eq q{CODE} ) {
			$obj_self->{_har_Data}{ref_CustomData}	= $ref_Data;
			}
		else {  # Undef undef
			$obj_self->{_har_Data}{ref_CustomData}	= undef;
			}

		store($obj_self->{_har_Data}, $obj_self->{_uri_Path});

		my $str_Caller	= (caller(0))[3];
		close($fh) or die qq{$str_Caller(): Unable to close "$obj_self->{_uri_Path}" properly\n};
		}

	return(true);
	}

=head3 C<GetCustomData>

 $ref_Data	= $object->GetCustomData();

Load the reference, formerly saved by C<SetCustomData>.
Returns C<undef> either it was never set or an error occurred.

=cut

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

	return($obj_self->{_har_Data}{ref_CustomData});
	}

sub _EndProcedure {
	foreach my $obj_self ( @obj_EndSelf ) {
		&DESTROY($obj_self);
		}
	}

=head1 LOCKING

Locking works like a traffic light: Only if honoured, it can do its magic. L<C<flock()>|https://perldoc.perl.org/functions/flock> works the same way: only if all members honour the lock, it can be guaranteed to work properly.
There are several methods implemented to prevent infinite locks through unexpectedly died processes.
But the core of this is the token handling itself, providing a FIFO locking mechanism. The first process which called C<TokenLock> is the first that will gain the lock. The last process, called C<TokenLock> has to wait until the second to last called C<TokenUnlock>.
C<TokenLock> is blocking. Until the former processes either call C<TokenUnlock> or unexpectedly died.

=head1 CAVEATS

Using C<SetCustomData> can lead to problems. For example, if a huge array is stored, the memory can exceed. However, even worse is: the more data is stored within, the slower the locking mechanism gets, because it has to write all the data every time it checks or changes the lock file.
Refer to L<GOOD PRACTICE> how to prevent this.

=head1 GOOD PRACTICE

=head3 Transferring huge amounts of data between processes

 # Parent
 my $obj_Lock	= IPC::LockTicket->New('MyApp');
 my $obj_IPC	= IPC::LockTicket->New('/var/tmp/MyApp/storage.ipc');
 $obj_Lock->MainLock(1);
 $obj_IPC->MainLock(1);
 ...

 # Child 1 has much data to transfer
 $obj_Lock->TokenLock();
 $obj_IPC->SetCustomData($referenceToHugeHashArray);
 $obj_Lock->TokenUnlock();
 ...

 # Child 2 shall work on the data
 $obj_Lock->TokenLock();
 my $referenceToHugeHashArray = $obj_IPC->GetCustomData();
 $obj_IPC->SetCustomData(undef);	# Cleare storage to prevent working on the same elements several times...
 $obj_Lock->TokenUnlock();		# ...and unlock fastly.

 if ( defined($referenceToHugeHashArray) ) {
	# Do something with the data...
	exit(0);
	}
 else {
	# Data was emptied or no data were saved yet.
	exit(0);
	}

Use dynamic naming for locking mechanisms only. This way, C<IPC::LockTicket> tries to find the best location to store the file on its own while you keep the file small.
For use of custom data transfer between processes, use full path notation and store on a slower, but huge partition.
This way the lock mechanism can keep its speed, but you can transfer huge data as well.
Maybe it is a better idea to use something like a database instead of a lock file for those situations. To consider this: the data is stored as a blob from L<Storable>. This works well if you write once and clear the data afterwards. But it will re-write the whole file every time C<SetCustomData> is called. This is inefficient if only a new hash pair shall be added and can make your app awfully slow. Better would be to prevent parallel database table access through IPC::LockTicket, so no redundant work happens, while databases are optimized to handle small amounts of data. Consider S<C<Child 2>> reading the whole table, then truncating it. After that S<C<Child 1>> might again write something new into the table.

=head3 Shared locks

It is possible to run C<MainLock(1)> within the children, but this is bad practice and strongly discouraged! Shared locks shall only be shared between the main processes (parents) while children only use the C<TokenLock> and C<TokenUnlock> methods.
The lock objects created through C<New('name')> can be copied though C<fork>ing.
But C<New> sets what is understood as the I<parent> PID to the calling process. C<MainLock> and C<MainUnlock> expect to be run within the I<parent> process.
C<TokenLock> is more optimized for speed than C<MainLock> is.

=head1 AUTHOR

Dominik Bernhardt, domasprogrammer@gmail.com

=head1 CREDITS

Thanks for the hard time, much to learn and ideas I got through:

=over 2

=item L<Storable|https://metacpan.org/pod/Storable>

=item L<IPC::Shareable|https://metacpan.org/pod/IPC::Shareable>

=item L<C<flock()>|https://perldoc.perl.org/functions/flock>

=back

=head1 SEE ALSO

L<perl(1)>, L<Storable|https://metacpan.org/pod/Storable>

=cut

1;
