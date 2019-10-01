FROM dodasts/centos:7-grid-tini-sshd as base

WORKDIR /etc/yum.repos.d

RUN useradd -ms /bin/bash condor \
    && yum --setopt=tsflags=nodocs -y update \
    && yum --setopt=tsflags=nodocs -y install \
        condor-all \
        gcc \
        gcc-c++ \
        make \
        openssh-clients \
        openssh-server \
        python-devel \
        python-pip \
    && yum clean all \
    && pip install --upgrade pip setuptools \
    && pip install j2cli paramiko psutil kazoo requests flask Flask-WTF

# Root home
WORKDIR /root

# condor_collector
EXPOSE 9618
# condor_negotiator
EXPOSE 9614
# condor_ckpt_server
EXPOSE 5651-5654
# condor_ports
EXPOSE 1024-2048
# condor env default values
ENV CONDOR_DAEMON_LIST="COLLECTOR, MASTER, NEGOTIATOR, SCHEDD, STARTD"
ENV CONDOR_HOST="\$(FULL_HOSTNAME)"
ENV CCB_ADDRESS_STRING=""
ENV NETWORK_INTERFACE_STRING=""
ENV CONDOR_SCHEDD_SSH_PORT=31042
ENV TUNNEL_FROM="UNDEFINED"
ENV TUNNEL_TO="UNDEFINED"
ENV SEC_DAEMON_AUTHENTICATION_METHODS=CLAIMTOBE
ENV SEC_CLIENT_AUTHENTICATION_METHODS=CLAIMTOBE
ENV SEC_NEGOTIATOR_AUTHENTICATION_METHODS=CLAIMTOBE
ENV SEC_ADVERTISE_STARTD_AUTHENTICATION_METHODS=CLAIMTOBE
ENV NUM_SLOTS=1 
ENV NUM_SLOTS_TYPE_1=1
ENV SLOT_TYPE_1="cpus=1, mem=4096"
ENV FLOCK_FROM=""
ENV FLOCK_TO=""
ENV FLOCK_TO_COL_NEG=""
ENV HOST_ALLOW_FLOCK=""

RUN mkdir -p /opt/dodas/htc_config \
    && mkdir -p /opt/dodas/fs_remote_dir \
    && mkdir -p /opt/dodas/health_checks \
    && mkdir -p /etc/skel/.ssh
COPY condor.sh /opt/dodas/
COPY ./health_checks/check_condor_processes.py /opt/dodas/health_checks/
COPY ./health_checks/check_cvmfs_folders.py /opt/dodas/health_checks/
COPY ./health_checks/check_ssh_server.py /opt/dodas/health_checks/
COPY ./health_checks/check_condor_master_ip.sh /opt/dodas/health_checks/
COPY ./health_checks/check_condor_schedd_tunnel.sh /opt/dodas/health_checks/
COPY cache.py /opt/dodas/
COPY ./config/condor_config_schedd.template /opt/dodas/htc_config/
COPY ./config/condor_config_master.template /opt/dodas/htc_config/
COPY ./config/condor_config_wn.template /opt/dodas/htc_config/
COPY webapp /opt/dodas/htc_config/webapp
RUN mkdir -p /var/log/form/

RUN ln -s /opt/dodas/condor.sh /usr/local/sbin/dodas_condor \
    && ln -s /opt/dodas/health_checks/check_condor_processes.py /usr/local/sbin/dodas_check_condor_processes \
    && ln -s /opt/dodas/health_checks/check_cvmfs_folders.py /usr/local/sbin/dodas_check_cvmfs_folders \
    && ln -s /opt/dodas/health_checks/check_ssh_server.py /usr/local/sbin/dodas_check_ssh_server \
    && ln -s /opt/dodas/health_checks/check_condor_master_ip.sh /usr/local/sbin/dodas_check_condor_master_ip \
    && ln -s /opt/dodas/health_checks/check_condor_schedd_tunnel.sh /usr/local/sbin/dodas_check_condor_schedd_tunnel \
    && ln -s /opt/dodas/cache.py /usr/local/sbin/dodas_cache

# CentOS uname characteristics
RUN mv /bin/uname /bin/uname_old
COPY ./bin/uname /bin/

FROM  base as build

RUN yum install -y git
RUN git clone https://github.com/htcondor/htcondor.git

WORKDIR /root/htcondor

RUN git checkout V8_9_3-branch

RUN yum install -y cmake autotools git cmake make gcc gcc-c++ gcc-fortran pam-devel libcurl libcurl-devel boost-devel pcre-devel libxml2-devel libuuid-devel glibc-static sqlite-devel patch python-devel bison flex openssl-devel nss-devel perl-Data-Dumper

#RUN ./configure_uw -DWITH_CREAM:BOOL=false -DWITH_GLOBUS:BOOL=false -DWITH_BLAHP:BOOL=false -DCLIPPED:BOOL=true -DWITH_BOINC:BOOL=false && make

RUN mkdir build2 && cd build2 && cmake ..

FROM build as production

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/dodas_condor"]
