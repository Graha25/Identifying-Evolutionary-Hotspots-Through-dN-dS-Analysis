#!/usr/bin/perl
use strict;
use warnings;
use GD::Graph::bars;
use GD::Graph::Data;

# Loading sequences from a FASTA file
sub load_sequences {
    my $file = shift;
    open my $fh, '<', $file or die "Cannot open file: $!\n";
    my @seqs;
    my $seq = '';
    while (<$fh>) {
        chomp;
        if (/^>/) { push @seqs, $seq if $seq; $seq = ''; }
        else { $seq .= $_; }
    }
    push @seqs, $seq if $seq;  # Add the last sequence
    close $fh;
    return @seqs;
}

# Calculating both dN and dS ratio and returning
sub calculate_dnds {
    my @sequences = @_;
    my $length = length($sequences[0]);

    # Check all sequences have the same length
    foreach my $seq (@sequences) {
        die "Error: Sequences must be the same length\n" if length($seq) != $length;
    }

    my ($dN, $dS) = (0, 0);
    
    for my $i (0 .. $length - 1) {
        my %column = map { substr($_, $i, 1) => 1 } @sequences;
        if (scalar keys %column > 1) { $dN++; }
        else { $dS++; }
    }

    my $ratio = $dS > 0 ? $dN / $dS : 'inf';
    return ($ratio, $dN, $dS, $length);
}

# Calculating GC content for all sequences
sub calculate_gc_content {
    my @seqs = @_;
    my $total_bases = 0;
    my $gc_count = 0;
    for my $seq (@seqs) {
        $total_bases += length($seq);
        $gc_count += ($seq =~ tr/GCgc//);
    }
    return $total_bases > 0 ? sprintf("%.2f", ($gc_count / $total_bases) * 100) : 0;
}

my @sequences = load_sequences('sequences.fasta');  # Replace with your FASTA file
my ($dnds_ratio, $dN, $dS, $length) = calculate_dnds(@sequences);
my $num_sequences = scalar @sequences;
my $gc_content = calculate_gc_content(@sequences);
my $variable_sites = $dN;
my $conserved_sites = $dS;
my $percent_variable = sprintf("%.2f", ($variable_sites / $length) * 100);

print "Number of sequences: $num_sequences\n";
print "Sequence length: $length\n";
print "Variable sites: $variable_sites\n";
print "Conserved sites: $conserved_sites\n";
print "Percentage variable sites: $percent_variable%\n";
print "GC content: $gc_content%\n";
print "dN/dS Ratio: $dnds_ratio\n";

my $interpretation;
if ($dnds_ratio eq 'inf' or $dnds_ratio > 1) {
    $interpretation = "Evolutionary change detected: Positive selection is occurring.";
} elsif ($dnds_ratio == 1) {
    $interpretation = "Neutral evolution detected: Mutations do not affect fitness.";
} else {
    $interpretation = "Purifying selection detected: Functional conservation is occurring.";
}
print "$interpretation\n";

my $data = GD::Graph::Data->new([
    ["dN", "dS"],
    [$dN,  $dS],
]) or die GD::Graph::Data->error;

my $graph = GD::Graph::bars->new(400, 300);
$graph->set(
    title     => 'dN vs dS',
    x_label   => 'Type',
    y_label   => 'Count',
    transparent => 0,
) or die $graph->error;

my $gd = $graph->plot($data) or die $graph->error;
open my $out, '>', 'dnds_plot.png' or die "Cannot write image: $!";
binmode $out;
print $out $gd->png;
close $out;

print "Graph saved as dnds_plot.png\n";

open my $html, '>', 'dnds_report.html' or die "Cannot write HTML file: $!";
print $html <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>dN/dS Analysis Report</title>
<style>
  body { font-family: Arial, sans-serif; margin: 20px; }
  table { border-collapse: collapse; width: 400px; margin-bottom: 20px; }
  th, td { border: 1px solid black; padding: 8px; text-align: center; }
  th { background-color: #f2f2f2; }
</style>
</head>
<body>
<h2>dN/dS Analysis Report</h2>

<h3>Summary Statistics</h3>
<ul>
  <li>Number of sequences: $num_sequences</li>
  <li>Sequence length: $length</li>
  <li>Variable sites: $variable_sites</li>
  <li>Conserved sites: $conserved_sites</li>
  <li>Percentage variable sites: $percent_variable%</li>
  <li>GC content: $gc_content%</li>
</ul>

<h3>dN/dS Results</h3>
<table>
  <tr><th>dN</th><th>dS</th><th>dN/dS Ratio</th></tr>
  <tr><td>$dN</td><td>$dS</td><td>$dnds_ratio</td></tr>
</table>

<p><strong>Interpretation:</strong> $interpretation</p>

<img src="dnds_plot.png" alt="dN vs dS bar chart" />

</body>
</html>
HTML

close $html;

print "HTML report saved as dnds_report.html\n";






