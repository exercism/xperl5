#!/usr/bin/env perl
use strict;
use warnings;
use feature qw<lexical_subs say>;

use YAML qw<LoadFile>;
use Path::Tiny qw<:DEFAULT cwd>;

use lib::gitroot qw<:lib :once>;
use Exercism::Generator;

use constant BASE_DIR => path(GIT_ROOT);

if ( !BASE_DIR->child('problem-specifications')->is_dir ) {
  warn
    "problem-specifications directory not found; exercise(s) may generate incorrectly.\n";
}
if ( !BASE_DIR->child( 'bin', 'configlet' )->is_file ) {
  warn
    "configlet not found; README.md file(s) will not be generated.\n";
}

my @exercises;

if (@ARGV) {
  my %arg_set = map { $_ => 1 } @ARGV;
  if ( $arg_set{'--all'} ) {
    push @exercises, $_->basename
      for BASE_DIR->child('exercises')->children;
  }
  else {
    @exercises = keys %arg_set;
  }
}
else {
  say 'No args given; working in current directory.';
  if ( path( '.meta', 'exercise-data.yaml' )->is_file ) {
    push @exercises, cwd->basename;
  }
  else {
    say
      '.meta/exercise-data.yaml not found in current directory; exiting.';
    exit 1;
  }
}

my @dir_not_found;
my @data_not_found;
for my $exercise (@exercises) {
  my $exercise_dir = BASE_DIR->child( 'exercises', $exercise );
  my $yaml = $exercise_dir->child( '.meta', 'exercise-data.yaml' );

  unless ( $exercise_dir->is_dir ) {
    push @dir_not_found, $exercise;
    next;
  }
  unless ( $yaml->is_file ) {
    push @data_not_found, $exercise;
    next;
  }
  print "Generating $exercise... ";

  my $data = LoadFile $yaml;
  my $generator
    = Exercism::Generator->new(
    { exercise => $exercise, data => $data } );

  $exercise_dir->child("$exercise.t")
    ->spew( { binmode => ':encoding(UTF-8)' }, $generator->test );
  $exercise_dir->child("$exercise.t")->chmod(0755);

  $exercise_dir->child( '.meta', 'solutions',
    $data->{exercise} . '.pm' )
    ->spew( { binmode => ':encoding(UTF-8)' }, $generator->example );

  $exercise_dir->child( $data->{exercise} . '.pm' )
    ->spew( { binmode => ':encoding(UTF-8)' }, $generator->stub );

  for ( BASE_DIR->child( 'bin', 'configlet' ) ) {
    system $_->realpath, 'generate', BASE_DIR, '--only', $exercise
      if $_->is_file;
  }

  say 'Generated.';
}

if (@dir_not_found) {
  warn 'exercise directory does not exist for: '
    . join( q| |, @dir_not_found ) . "\n";
}
if (@data_not_found) {
  warn '.meta/exercise-data.yaml not found for: '
    . join( q| |, @data_not_found ) . "\n";
}
