FROM dodasts/tts-cache:v0.1.3-k8s-6 as TTS

FROM dodasts/centos:7-grid-tini-sshd as BASE

WORKDIR /etc/yum.repos.d

RUN useradd -ms /bin/bash condor \
    && wget http://research.cs.wisc.edu/htcondor/yum/repo.d/htcondor-stable-rhel7.repo \
    && wget http://research.cs.wisc.edu/htcondor/yum/RPM-GPG-KEY-HTCondor \
    && rpm --import RPM-GPG-KEY-HTCondor \
    && yum --setopt=tsflags=nodocs -y update \
    && yum --setopt=tsflags=nodocs -y install \
        condor-all-8.8.2-1.el7 \
        gcc \
        gcc-c++ \
        make \
        openssh-clients \
        openssh-server \
        python-devel \
        python-pip \
    && yum clean all \
    && pip install --upgrade pip setuptools \
    && pip install j2cli paramiko psutil kazoo requests flask Flask-WTF htcondor \
    && systemctl disable condor

FROM BASE as APP

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

## START FERMI SPECIFIC

ENV CONDABIN="${CONDAPFX}/bin/conda"
ENV CONDAPFX="/cvmfs/fermi.local.repo/anaconda3"

# RUN yum install -y sqlite-devel \
#   autoconf \
#   automake \
#   bzip2-devel \
#   emacs \
#   gcc \
#   gcc-c++ \
#   gcc-gfortran \
#   git \
#   libpng-devel \
#   libSM-devel \
#   libX11-devel \
#   libXdmcp-devel \
#   libXext-devel \
#   libXft-devel \
#   libXpm-devel \
#   libXrender-devel \
#   libXt-devel \
#   make \
#   mesa-libGL-devel \
#   ncurses-devel \
#   openssl-devel \
#   patch \
#   perl \
#   perl-ExtUtils-MakeMaker \
#   readline-devel \
#   sqlite-devel \
#   sudo \
#   tar \
#   vim \
#   wget \
#   which \
#   zlib-devel && \
# yum clean all && \
# rm -rf /var/cache/yum

# ENV PATH="/cvmfs/fermi.local.repo/anaconda3/bin:${PATH}"


# ENV HEADAS="/cvmfs/fermi.local.repo/ftools/x86_64-pc-linux-gnu-libc2.17"

# ## END OF FERMI SPECIFIC 

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

COPY --from=0 /usr/local/bin/tts-cache /usr/local/bin/tts-cache

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/dodas_condor"]

FROM APP as CMS

COPY cms/condorconfig/* /etc/condor/
COPY cms/config.d/* /etc/condor/config.d/

COPY cms/dodas_bin/*  /usr/local/bin/

RUN chmod +x /usr/local/bin/dodasexe_pre.sh \
    && chmod +x /usr/local/bin/dodasexe.sh \
    && chmod +x /usr/local/bin/dodas.sh

RUN mkdir -p /etc/condor/certs \
    && cp /etc/condor/config.d/condor_mapfile /etc/condor/certs/condor_mapfile \
    && rm /etc/condor/config.d/condor_mapfile

WORKDIR /root

# Download validation script
RUN wget https://gitlab.cern.ch/CMSSI/CMSglideinWMSValidation/raw/master/singularity_validation.sh \
    && wget https://gitlab.cern.ch/CMSSI/CMSglideinWMSValidation/raw/master/singularity_wrapper.sh -O /usr/local/libexec/singularity_wrapper.sh

RUN   chmod +x /usr/local/libexec/singularity_wrapper.sh \
    && chmod 0755 /usr/local/libexec/singularity_wrapper.sh \
    && chown condor:condor /usr/local/libexec/singularity_wrapper.sh


ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dodas.sh"]