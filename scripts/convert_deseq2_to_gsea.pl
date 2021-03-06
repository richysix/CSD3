#!/usr/bin/env perl

# PODNAME: convert_deseq2_to_gsea.pl
# ABSTRACT: Convert DESeq2 output to GSEA input

## Author     : Ian Sealy
## Maintainer : Ian Sealy
## Created    : 2017-10-26

use warnings;
use strict;
use autodie;
use Getopt::Long;
use Pod::Usage;
use Carp;
use version; our $VERSION = qv('v0.1.0');

use File::Spec;
use File::Path qw( make_path );

# Default options
my $output_dir;
my $all_file;
my $samples_file;
my $exp_condition;
my $con_condition;
my ( $debug, $help, $man );

# Get and check command line options
get_and_check_options();

# Get samples
my %condition_for;
my @all_samples;
open my $samples_fh, '<', $samples_file;
while ( my $line = <$samples_fh> ) {
    chomp $line;
    my ( $sample, $condition ) = split /\t/xms, $line;
    $condition_for{$sample} = $condition;
    push @all_samples, $sample;
}
close $samples_fh;

# Remove samples with other conditions
my @samples = grep {
         $condition_for{$_} eq $exp_condition
      || $condition_for{$_} eq $con_condition
} @all_samples;

# Write CLS file
my $cls_file = File::Spec->catfile( $output_dir, 'samples.cls' );
open $samples_fh, '>', $cls_file;
printf {$samples_fh} "%d 2 1\n", scalar @samples;
printf {$samples_fh} "# %s %s\n", $exp_condition, $con_condition;
my @classes = map { $condition_for{$_} eq $exp_condition ? 0 : 1 } @samples;
printf {$samples_fh} "%s\n", ( join q{ }, @classes );
close $samples_fh;

# Get headings, normalised counts and score
open my $all_fh, '<', $all_file;    ## no critic (RequireBriefOpen)
my $header = <$all_fh>;
chomp $header;
my @headings = split /\t/xms, $header;
my %sample_to_col;
my $col = -1;                       ## no critic (ProhibitMagicNumbers)
foreach my $heading (@headings) {
    $col++;
    if ( $heading =~ m/\s normalised \s count \z/xms ) {
        $heading =~ s/\s normalised \s count \z//xms;
        $sample_to_col{$heading} = $col;
    }
}
my @genes;
my %counts_for;
my %score_for;
while ( my $line = <$all_fh> ) {
    chomp $line;
    my @fields = split /\t/xms, $line;
    next if $fields[2] eq 'NA';    # No adjusted p-value
    push @genes, $fields[0];
    foreach my $sample (@samples) {
        push @{ $counts_for{$sample} }, $fields[ $sample_to_col{$sample} ];
    }
    ## no critic (ProhibitMagicNumbers)
    $score_for{ $fields[0] } =
      -log( $fields[1] ) / log(10) * ( $fields[3] < 0 ? -1 : 1 );
    ## use critic
}
close $all_fh;

# Write GCT file
my $gct_file = File::Spec->catfile( $output_dir, 'counts.gct' );
open my $gct_fh, '>', $gct_file;    ## no critic (RequireBriefOpen)
printf {$gct_fh} "%s\n", '#1.2';
printf {$gct_fh} "%d\t%d\n", scalar @genes, scalar @samples;
printf {$gct_fh} "NAME\tDescription\t%s\n", ( join "\t", @samples );
foreach my $i ( 0 .. ( scalar @genes ) - 1 ) {
    my @counts;
    foreach my $sample (@samples) {
        push @counts, $counts_for{$sample}->[$i];
    }
    printf {$gct_fh} "%s\tNA\t%s\n", $genes[$i], ( join "\t", @counts );
}
close $gct_fh;

# Write RNK file
my $rnk_file = File::Spec->catfile( $output_dir, 'genes.rnk' );
open my $rnk_fh, '>', $rnk_file;
foreach my $gene (@genes) {
    printf {$rnk_fh} "%s\t%s\n", $gene, $score_for{$gene};
}
close $rnk_fh;

# Get and check command line options
sub get_and_check_options {

    # Get options
    GetOptions(
        'output_dir=s'    => \$output_dir,
        'all_file=s'      => \$all_file,
        'samples_file=s'  => \$samples_file,
        'exp_condition=s' => \$exp_condition,
        'con_condition=s' => \$con_condition,
        'debug'           => \$debug,
        'help'            => \$help,
        'man'             => \$man,
    ) or pod2usage(2);

    # Documentation
    if ($help) {
        pod2usage(1);
    }
    elsif ($man) {
        pod2usage( -verbose => 2 );
    }

    if ( defined $output_dir ) {
        $output_dir =~ s/\/ \z//xms;
    }

    if ( !$output_dir ) {
        pod2usage("--output_dir must be specified\n");
    }
    if ( !$all_file ) {
        pod2usage("--all_file must be specified\n");
    }
    if ( !$samples_file ) {
        pod2usage("--samples_file must be specified\n");
    }
    if ( !$exp_condition ) {
        pod2usage("--exp_condition must be specified\n");
    }
    if ( !$con_condition ) {
        pod2usage("--con_condition must be specified\n");
    }

    return;
}

__END__
=pod

=encoding UTF-8

=head1 NAME

convert_deseq2_to_gsea.pl

Convert DESeq2 output to GSEA input

=head1 VERSION

version 0.1.0

=head1 DESCRIPTION

This script takes an RNA-Seq output file and samples file and converts them for
use with GSEA.

=head1 EXAMPLES

    perl \
        convert_deseq2_to_gsea.pl \
        --output_dir gsea-hom_vs_wt \
        --all_file deseq2-hom_vs_wt/all.tsv \
        --samples_file deseq2-hom_vs_wt/samples.txt \
        --exp_condition hom \
        --con_condition wt

=head1 USAGE

    convert_deseq2_to_gsea.pl
        [--output_dir dir]
        [--all_file file]
        [--samples_file file]
        [--exp_condition condition]
        [--con_condition condition]
        [--debug]
        [--help]
        [--man]

=head1 OPTIONS

=over 8

=item B<--output_dir DIR>

Directory in which to create output files.

=item B<--all_file FILE>

RNA-Seq output file (e.g. all.tsv).

=item B<--samples_file FILE>

DESeq2 samples file (e.g. samples.txt). The order of samples in the samples file
determines the order of the columns in the output.

=item B<--exp_condition CONDITION>

Experimental condition from sample files.

=item B<--con_condition CONDITION>

Control condition from sample files.

=item B<--debug>

Print debugging information.

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print this script's manual page and exit.

=back

=head1 DEPENDENCIES

None

=head1 AUTHOR

=over 4

=item *

Ian Sealy

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Genome Research Ltd.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
