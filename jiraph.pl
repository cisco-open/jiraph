#!/usr/bin/perl

# SPDX-License-Identifier: MIT
# 
# Copyright 2024 Cisco Systems, Inc. and its affiliates
# 
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
# 
# Author: sdworkis@cisco.com (Scott Dworkis)

# http://bloodgate.com/perl/graph/manual/
# https://metacpan.org/pod/Graph::Easy
#
# seems some bug where edges get lost sometimes... maybe try to build
# all nodes first then add edges (and don't create node by creating
# it's source edge before populating it's description).  actually i
# realized this is probably just when a graph gets too big,
# graph::easy layouter gives up and drops edges
#
# consider trying building a dot and using the graph-easy converter
#
# handle curl/rest fails better
#
# consider a non json paramaterization

use strict;
use Data::Dumper;
use JSON;
use Getopt::Long;
use Graph::Easy;
use CGI qw(escape);

my(%opts);
my(@opts)=('token=s',
	   'config_ticket_summary=s',
           'ascii',
           'unicode',
           'svg',
#tbd       'nosummary',
	   'team=s',
	   'proj=s',
	   'prune=s',
#tbd       'nolinks',
           'quiet',
    );
die unless GetOptions(\%opts,@opts);

die 'token required' unless($opts{token});
die 'one or more seed issues required' unless(scalar(@ARGV));
die '--unicode --ascii --svg are mutually exclusive' if($opts{unicode} + $opts{ascii} + $opts{svg} > 1);

$opts{unicode} = 1 if($opts{unicode} + $opts{ascii} + $opts{svg} == 0);
my($graph) = Graph::Easy->new();
$graph->set_attributes({textwrap => 'auto'});
$graph->timeout(60);
#$graph->debug(1);
my($entry) = shift(@ARGV);
my($entryg) = $graph->add_node($entry);
$entryg->set_attributes({border => 'wide'});
my($incepic) = {};
for my $epic (@{$opts{incepic}}){
  $incepic->{$epic} = 1;
}
my($seeds)={};
for($entry, @ARGV){
  $seeds->{$_} = 1;
}
my($q) = [keys(%$seeds)];
my($prunea);
if($opts{prune}){
  $prunea = [split(',', $opts{prune})];
}
my($seen) = {};
for(@$prunea){
  $seen->{$_} = 1;
}

# fetch config ticket if it exists
$opts{config_ticket_summary} ||= 'jiraph_config';
my($jiraph_config) = escape(qq{summary ~ "$opts{config_ticket_summary}" ORDER BY updated DESC});
$jiraph_config = decode_json(
  scalar(
    `curl -s --header "Authorization: Bearer $opts{token}" 'https://jira.it.umbrella.com/rest/api/2/search?jql=$jiraph_config'`));
$jiraph_config = $jiraph_config->{issues}[0]{fields}{description};
($jiraph_config) = $jiraph_config =~ /.*noformat.(.*?).noformat/smg;
$jiraph_config = decode_json($jiraph_config);
my($teama) = $jiraph_config->{team};
if($opts{team}){
  $teama = [split(',', $opts{team})];
}
my($team) = {};
for(@$teama){
  $team->{$_} = 1;
}
my($proja) = $jiraph_config->{proj};
if($opts{proj}){
  $proja = [split(',', $opts{proj})];
}
my($proj) = {};
for(@$proja){
  $proj->{$_} = 1;
}

binmode(STDOUT, ":encoding(UTF-8)");

# interrupt runaway recursions and show current graph
$SIG{INT}=sub{draw();exit 1};

while(scalar(@$q)){
  my($nodekey) = shift(@$q);
  next if($seen->{$nodekey}++);
  print STDERR "$nodekey." unless($opts{quiet});
  my($nodeobj) = decode_json(
    scalar(
      `curl -s --header "Authorization: Bearer $opts{token}" https://jira.it.umbrella.com/rest/api/latest/issue/$nodekey`));
  die unless($nodeobj);
  my($nodeg) = $graph->add_node($nodekey);
  unless($opts{nosummary}){
    my($esc) =
	"$nodeobj->{fields}{summary} - " .
	"$nodeobj->{fields}{reporter}{name} / $nodeobj->{fields}{assignee}{name} - " .
	"$nodeobj->{fields}{status}{name} - " .
	($nodeobj->{fields}{updated} =~ /^(.*)T/)[0];
    $esc =~ s/\|/\\\|/smg;
    $nodeg->set_attributes({label => "$nodekey " . $esc});
  }
  next unless($proj->{$nodeobj->{fields}{project}{key}} ||
	      $team->{$nodeobj->{fields}{reporter}{name}} ||
	      $team->{$nodeobj->{fields}{assignee}{name}} ||
              $seeds->{$nodekey});
  if($nodeobj->{fields}{issuetype}{name} eq 'Epic'){
    $nodeg->set_attributes({border => 'bold'})
	unless($nodekey eq $entry);
    if($seeds->{$nodekey}){
      my($epiclinks) = decode_json(
	scalar(
	  `curl -s --header "Authorization: Bearer $opts{token}" https://jira.it.umbrella.com/rest/api/2/search?jql=\%22Epic+Link\%22=$nodekey`));
      for my $link (@{$epiclinks->{issues}}){
        next if($seen->{$link->{key}});
	print STDERR '!' unless($opts{quiet});
	$graph->add_edge_once($nodekey, $link->{key});
	push(@$q, $link->{key});
      }
    }else{
      next;
    }
  }
  if($nodeobj->{fields}{parent}){
    next if($seen->{$nodeobj->{fields}{parent}{key}});
    $graph->add_edge_once($nodeobj->{fields}{parent}{key}, $nodekey);
    push(@$q, $nodeobj->{fields}{parent}{key});
    print STDERR '^' unless($opts{quiet});
  }
  if($nodeobj->{fields}{issuelinks}){
    for my $link (@{$nodeobj->{fields}{issuelinks}}){
      if($link->{inwardIssue}){
        next if($seen->{$link->{inwardIssue}{key}});
	next if($link->{type}{inward} eq 'is cloned by');
	print STDERR '<' unless($opts{quiet});
	$graph->add_edge_once($link->{inwardIssue}{key}, $nodekey);
	push(@$q, $link->{inwardIssue}{key});
      }
      if($link->{outwardIssue}){
        next if($seen->{$link->{outwardIssue}{key}});
	next if($link->{type}{outward} eq 'clones');
	print STDERR '>' unless($opts{quiet});
	$graph->add_edge_once($nodekey, $link->{outwardIssue}{key});
	push(@$q, $link->{outwardIssue}{key});
      }
    }
  }
  if($nodeobj->{fields}{subtasks}){
    for my $link (@{$nodeobj->{fields}{subtasks}}){
      next if($seen->{$link->{key}});
      print STDERR '/' unless($opts{quiet});
      $graph->add_edge_once($nodekey, $link->{key});
      push(@$q, $link->{key});
    }
  }
  # think there's a couple ways to list customfields that are epics, but hard code for now
  if($nodeobj->{fields}{customfield_10700} &&
     !($seen->{$nodeobj->{fields}{customfield_10700}})){
    $graph->add_edge_once($nodeobj->{fields}{customfield_10700}, $nodekey);
    print STDERR '%' unless($opts{quiet});
    push(@$q, $nodeobj->{fields}{customfield_10700});
  }
  print STDERR '#' unless($opts{quiet});
}

print "\n";
for my $root ($graph->source_nodes()){
  $root->set_attributes({textwrap => 35})
}

sub draw{
  print "\n";
  if($opts{ascii}){
    print $graph->as_ascii();
  }elsif($opts{unicode}){
    print $graph->as_boxart();
  }elsif($opts{svg}){
    print $graph->as_svg();
    exit 0;
  }

  for(sort
# sort by date probably makes more sense than sort by edge rank since it's pretty visible in the graph
#      {scalar(keys(%{$b->{edges}})) <=> scalar(keys(%{$a->{edges}}))}
      {($b->{att}{label} =~ / (\S*)$/)[0] cmp ($a->{att}{label} =~ / (\S*)$/)[0]}
      $graph->nodes()){
    my($summary) = $_->{att}{label};
    $summary =~ s/^\S*\s//;
    my($d) = ($summary =~ / - (\S*)$/);
    $summary =~ s/ - $d$//;
    print(sprintf("%-50s %s","https://jira.it.umbrella.com/browse/$_->{name}"," $d $summary (" . scalar(keys(%{$_->{edges}})) . ")\n"));
  }
}

draw();
