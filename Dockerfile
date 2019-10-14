FROM dodasts/htcondor:build as build

WORKDIR /root/htcondor

RUN git checkout V8_9_3-branch

RUN cmake3 -DWITH_OPENSSL:BOOL=true -DWITH_PYTHON_BINDINGS:BOOL=false -DWITH_CREAM:BOOL=false -DWITH_GLOBUS:BOOL=false -DWITH_BLAHP:BOOL=false -DCLIPPED:BOOL=true -DWITH_BOINC:BOOL=false -DCMAKE_INSTALL_PREFIX=/usr .  && make 

RUN make install

FROM build as exec

WORKDIR /root

RUN rm -fr /root/htcondor

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/dodas_condor"]

