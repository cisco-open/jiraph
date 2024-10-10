# Copyright 2024 Cisco Systems, Inc. and its affiliates
# Author: sdworkis@cisco.com (Scott Dworkis)
FROM ubuntu
ENV TZ=US/Pacific
ENV LC_ALL=en_US.UTF-8
RUN apt-get update && apt-get install -y locales && locale-gen en_US.UTF-8
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get install -y curl emacs-nox git screen openssh-client dialog rlwrap perl libjson-perl libgraph-easy-perl libcgi-pm-perl
COPY jiraph.pl jiraph.pl
