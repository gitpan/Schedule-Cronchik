package Schedule::Cronchik;
use strict;

use vars qw($VERSION);

$VERSION='0.1';

sub new {
        my $this = shift;
        my $class = ref($this) || $this;
        my $self = {};
        $self->{entry}  = shift;
        $self->{code}   = shift;
        $self->{lrmark} = shift;
        bless $self, $class;
        return $self;
}

# min hour day month weekday command
# 

sub expand{
    my($s,$start,$end)=@_;
    return ($start .. $end) if $s eq '*';
    my(@per)=split /,/, $s;
    my(@ev);

    for(@per){
       if(/^\d\d?$/){
          push @ev, $_;
          next;
       }
       if(/^(\d\d?)-(\d\d?)$/){
         push @ev, ($1 .. $2);
         next;
       }
       return ();
    }
    return sort @ev;
}

sub run{
 my $self=shift;
 my %periods=(
              min   => { per => [0,59], i => 1, adj => sub {return shift } },
              hour  => { per => [0,23], i => 2, adj => sub {return shift } },
              day   => { per => [1,31], i => 3, adj => sub {return shift } },
              month => { per => [1,12], i => 4, adj => sub {return shift()+1 } },
              wday  => { per => [1,7 ], i => 6, adj => sub {return shift()+1 } },
             );

 my (@ltime)= localtime( (stat $self->{lrmark})[9]);
 my (@ctime)= localtime();

 my $s=$self->{entry};
 my(%entry, @expanded);

 ($entry{min}, $entry{hour}, $entry{day}, $entry{month}, $entry{wday}, $entry{command})=
    split ' ', $s, 6;

 my $borrow=0;
 for my $k (qw(min hour day month) ){
   my $i = $periods{$k}{i};
   $ltime[$i] = $periods{$k}{adj}->($ltime[$i]);
   $ctime[$i] = $periods{$k}{adj}->($ctime[$i]);  
   $entry{$k}= [ expand($entry{$k}, @{ $periods{$k}{per} } ) ];
 }

 my $ltime = sprintf "%02d%02d%02d%02d", @ltime[4,3,2,1];
 my $rtime;
 my $ctime = sprintf "%02d%02d%02d%02d", @ctime[4,3,2,1];

 COMMON: for my $month (reverse @{$entry{month}}){
    next if $month > $ctime[4];
    for my $day (reverse @{$entry{day}}){
       next if $day > $ctime[3];
       for my $hour (reverse @{$entry{hour}}){
         next if $hour > $ctime[2];
         for my $min (reverse @{$entry{min}}){
           $rtime = sprintf "%02d%02d%02d%02d", $month, $day,$hour,$min;
           last COMMON if $rtime le $ctime;
         }
       }
    }
 }

 open MARK, $self->{lrmark};
 my $lrtime=<MARK>;
 chomp $lrtime;
 close MARK;
 if ( !$lrtime ){
      open MARK, '>' . $self->{lrmark};
      eval "flock MARK,2";
      print MARK 1;
      eval "flock MARK,8";
      close MARK;
      return 0;
 }

 if ( $ltime le $rtime and $rtime le $ctime and $rtime ne $lrtime){
    open MARK, '>' . $self->{lrmark};
    eval "flock MARK,2";
    $self->{code}->();
    print MARK $rtime;
    eval "flock MARK,8";
    close MARK;
    return 1;
 }
 return 0;
}

1;

__END__

=head1 NAME

Schedule::Cronchik - a cron-like addition to CGI scripts or something like it.

=head1 SYNOPSIS
 
 use Schedule::Cronchik;

 my $cron = new Schedule::Cronchik("0,10,20,30,40,50 * * * *", \&do_regular_task, "/tmp/lr.mark");
 $cron->run();

=head1 DESCRIPTION
 
Sometimes I need a task, peformed on regular basis. Unfortunately, not so
much hostings allows you to write your own crontabs, and getting a more
powerful hosting is too for your (or mine) task. Well, this module give
you a partial solution. 

=head1 METHODS

=over 4

=item C<new(I<entry>,I<coderef>,I<markfile>)>

create a new Schedule::Cronchik object.

=over 8

=item PARAMETERS 

=over 12

=item C<entry>

a cron-like entry with same behavoir. Note: the last field, a
week day, now is simply ignored.

=item C<coderef>

a reference to code to run when at desired time

=item C<markfile>

a filename for file where information about last run will be stored

=back

=back

=item C<run()>

a method to start execution of specified tasks. Return 0 if nothing
happened or 1 when C<coderef> was executed


=back

=head1 AUTHOR

Ivan Frolcov B<ifrol@cpan.org>
