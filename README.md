# Jiraph - Jira graph of neighboring issues

Ticket/issue systems at big companys are an ocean to drown in.  The
idea here is to surface an island with friendly beaches around a
particular seed ticket/issue.  This script crawls related tickets with
various pruning or constraining or extending strategies:

* Constrain the crawl to issues directly connected to particular
  projects - if you constrain to project A while exploring around seed
  issue A-123, and if A-123 relates to an issue with project B, which
  in turn relates to an issue in project C, only show those issues
  from project A and B

* Extend the crawl to issues connected to particular people - if you
  are interested in person i and j, and if an otherwise pruned issue C
  is reported by or assigned to person i or j, crawl it.

* Prune broad connector issues - by default, do not crawl epics or
  clones (unless they are a seed issue)... they tend to overbroaden
  the crawl

* Prune explicitly specified sets of issues

# Installing

You'll need to obtain a jira token.  Create the token on your jira profile page:

https://jira.example.com/secure/ViewProfile.jspa

Then build this docker container to pull in requisite packages

`docker build -t jiraph .`

# Usage

You should specify a comma separated list of projects and teammates
with --proj and --team option, or better yet by default these lists
can be shared in a "config ticket" in jira itself, and jiraph will
search for a ticket with the string "jiraph_config" in the summary, or
with a string given by the --config_ticket_summary option.  Jiraph
will look for json in the description surrounded by {noformat} tags.
The json should look something like:

```
{noformat}
{
   "proj" : ["PROJA","PROJB"],
   "team" : ["peter","paul","mary"]
}
{noformat}
```

The simplest invocation using a default proj/team config looks like:

`docker run --rm -ti --name jiraph jiraph bash -c "perl jiraph.pl --token '............................................' PROJ-123 | less -Si"`

This will use the config constraints to show a graph of issues near
seed issue PROJ-123.  It is highly advised to use `less -Si` to view
the graph, otherwise line wrapping will ruin the view of any
nontrivial graph.  Plus then you can search it interactively.  Issue
nodes will show the issue key, summary, reporter, assignee, status,
and last updated timestamp.  The first seed issue will have a bold
border around it, and any connected epics will have a slightly lighter
border around it (remember epics may be connected but would not be
crawled by default).  It will also dump a list of seen issue links
reverse sorted by update time.

With enough exploration and use, soon enough you'll learn how vast the
issue ocean is, jiraph will seem to crawl forever and lose all hope of
building a useful graph.  This means you'll need to develop some
pruning.  When this happens, you can interrupt the crawl with ctrl-c
and jiraph will draw what it's crawled so far.  Unless you used the
--quiet option, you'll see crawl progress on STDERR and any issues
with a large number of trailing symbols (the symbols represent issue
relations to follow/crawl) are likely candidates of places you'll want
to prune and the retry the crawl.  The partial graph can also help
understand how the problematic issue wound up being connected to your
crawl, or perhaps instead if there is some long linear chain that's
bloating the crawl that then can be pruned.  A list of issues to prune
can be provided as a comma separated list to the --prune option.

# More examples

Todo - probably create some mock ticket structures

Todo - get some animated gif tips to show interactions on real
nontrivial issues - interrupted crawls, less -S pager scrolling,
terminal zoom in/out, incremental pruning workflow

# Caveats

This tool uses the perl Graph::Easy module, which treats the |
character specially... so any issue summaries that include this
character will display it escaped with a backslash.

Crawled relationships include normal issue relationships, subtasks,
epic parents, and epic children if the parent was given as a seed.
Clones are not crawled.

The layouter seems to break down once graph gets to a certain size.
You'll need to work on pruning if this is a problem for a your
particular use/study (probably, but not necessarily).

# Future

* Add attachment count to label/summary (nice relevance/importance
  signal, maybe better than edge rank)

* Prune by create or update time

* Prune projects and people similar to issue prune list

* Read configs from local file and/or from shared jira "config
  ticket".  Config ticket could default to one based on jira token
  user so that even it would not need any special command line
  parameter or local config

* Allow incremental proj and team list changes instead of whole list
  replacement

* Read all options and arguments as part of the config, not just
  projects and people.  Allow incremental command line changes for all
  of these.

* Consider how subgraphs could be helpful... although i think that
  implies nontrivial clusters of nodes with only a single edge
  connecting the clusters and i don't know how common of a pattern
  this is in jira

* Add team comment activity as a similar extender to reporter/assignee



# Copyright 2024 Cisco Systems, Inc. and its affiliates
# Author: sdworkis@cisco.com (Scott Dworkis)
