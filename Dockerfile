FROM rockylinux:8.6.20227707

COPY openlico-portal/dist /usr/share/openlico-portal/
COPY openlico-docker/authselect /usr/share/authselect/vendor/nslcd/
ARG pypi_url
ENV pypi_url=${pypi_url}

RUN dnf install -y epel-release
RUN dnf install -y http://repos.openhpc.community/OpenHPC/2/EL_8/x86_64/ohpc-release-2-1.el8.x86_64.rpm
RUN dnf install -y dnf-plugins-core
RUN dnf config-manager --set-enabled powertools
RUN dnf install -y lua lua-posix lua-filesystem tcl tar gzip zip unzip vim procps net-tools openssh-clients git \
                   ohpc-slurm-client authselect nss-pam-ldapd sudo wget python3-cffi python36 pango libuser python3-libuser novnc \
                   'perl(Digest::SHA)' 'perl(HTML::TreeBuilder)' 'perl(HTTP::Request)' 'perl(JSON)' 'perl(LWP::Protocol::https)' 'perl(LWP::UserAgent)' 'perl(MIME::Base64)' \
                   gettext crontabs lmod-ohpc
RUN authselect select nslcd with-mkhomedir --force

#mariadb
RUN dnf install --nodocs -y mariadb-server  \
    && sed -i "/\[mysqld\]/a\max-connections=1024" /etc/my.cnf.d/mariadb-server.cnf

#redis
RUN  dnf module reset redis \
     && dnf module enable -y redis:6 \
     && dnf install -y redis

#influxdb
RUN dnf install --nodocs -y https://dl.influxdata.com/influxdb/releases/influxdb-1.11.1.x86_64.rpm

#nginx
RUN  dnf module reset nginx \
     && dnf module enable -y nginx:1.20 \
     && dnf install -y nginx nginx-mod-http-perl

#singularity
RUN dnf install -y singularity-ce

RUN mkdir -p /etc/lico \
    && mkdir -p /var/run/lico  \
    && mkdir -p /var/lib/lico/core/templates/ \
    && mkdir -p /var/lib/lico/core/alert/scripts/ \
    && mkdir -p /var/lib/lico/core/billing/ \
    && mkdir -p /var/log/lico/

COPY openlico /opt/build/openlico/


RUN cp /opt/build/openlico/core/etc/lico.pam  /etc/pam.d/lico  \
    && cp -r  /opt/build/openlico/core/templates/* /var/lib/lico/core/templates/
RUN rm -rf /var/lib/lico/core/templates/downstream.yml

COPY openlico-docker/scripts/* /opt/
COPY openlico-docker/conf/ldap.conf /etc/openldap/

RUN  cd /opt/build/openlico/  \
      && /usr/bin/pip3 install --no-cache-dir --upgrade pip \
      && /usr/bin/pip3 config set global.index-url ${pypi_url} \
      && msgfmt -cv core/apps/alert/lico/core/alert/locale/en/LC_MESSAGES/django.po -o core/apps/alert/lico/core/alert/locale/en/LC_MESSAGES/django.mo \
      && msgfmt -cv core/apps/alert/lico/core/alert/locale/sc/LC_MESSAGES/django.po -o core/apps/alert/lico/core/alert/locale/sc/LC_MESSAGES/django.mo \
      && msgfmt -cv core/apps/job/lico/core/job/locale/en/LC_MESSAGES/django.po -o core/apps/job/lico/core/job/locale/en/LC_MESSAGES/django.mo \
      && msgfmt -cv core/apps/job/lico/core/job/locale/sc/LC_MESSAGES/django.po -o core/apps/job/lico/core/job/locale/sc/LC_MESSAGES/django.mo \
      && msgfmt -cv core/apps/monitor/lico/core/monitor_host/locale/en/LC_MESSAGES/django.po -o core/apps/monitor/lico/core/monitor_host/locale/en/LC_MESSAGES/django.mo \
      && msgfmt -cv core/apps/monitor/lico/core/monitor_host/locale/sc/LC_MESSAGES/django.po -o core/apps/monitor/lico/core/monitor_host/locale/sc/LC_MESSAGES/django.mo \   
      && msgfmt -cv core/apps/operation/lico/core/operation/locale/en/LC_MESSAGES/django.po -o core/apps/operation/lico/core/operation/locale/en/LC_MESSAGES/django.mo \
      && msgfmt -cv core/apps/operation/lico/core/operation/locale/sc/LC_MESSAGES/django.po -o core/apps/operation/lico/core/operation/locale/sc/LC_MESSAGES/django.mo \   
      && msgfmt -cv core/apps/accounting/lico/core/accounting/locale/en/LC_MESSAGES/django.po -o core/apps/accounting/lico/core/accounting/locale/en/LC_MESSAGES/django.mo \
      && msgfmt -cv core/apps/accounting/lico/core/accounting/locale/sc/LC_MESSAGES/django.po -o core/apps/accounting/lico/core/accounting/locale/sc/LC_MESSAGES/django.mo \   
      && /usr/bin/pip3 install --no-cache-dir   -r requirements.txt

RUN ln -s /usr/local/bin/lico /usr/bin/lico \
      && ln -s /usr/local/bin/gunicorn  /usr/bin/gunicorn 

RUN getent group lico || groupadd -r lico && \
    getent passwd lico || useradd -r -d /var/lib/lico -g lico -s /sbin/nologin -c "LiCO HPC/AI Cluster" lico

RUN dnf install -y google-droid-sans-fonts

COPY  openlico/core/etc  \
      openlico/daemon/confluent-proxy/etc/confluent-proxy.ini \
      openlico/daemon/mail-agent/etc/mail-agent.ini \
      openlico/daemon/file-manager/etc/file-manager.ini \
      openlico/daemon/async-task/etc/async-task.ini \
      openlico-portal/etc/openlico-portal.conf \
      openlico-portal/etc/openlico-portal.conf.example \
      /etc/lico/
COPY  openlico/daemon/confluent-proxy/etc/lico.logging.d/confluent-proxy.ini  \
      openlico/daemon/mail-agent/etc/lico.logging.d/mail-agent.ini \
      openlico/daemon/file-manager/etc/lico.logging.d/file-manager.ini \
      openlico/daemon/async-task/etc/lico.logging.d/async-task.ini \
      /etc/lico/lico.logging.d/
COPY     openlico-docker/supervisor  /etc/lico/lico.supervisor.d/
COPY     openlico-portal/nginx  /etc/nginx/conf.d/
COPY     nginx/ssl  /etc/nginx/ssl/
RUN      sed -i '$a SINGULARITY_PATH = "/usr/bin/singularity"' /etc/lico/lico.ini.d/container.ini && \
         sed -i 's/USE_LIBUSER = false/USE_LIBUSER = true/g' /etc/lico/lico.ini.d/user.ini


RUN chmod 655 /opt/init && chmod 655 /opt/start

CMD ["/opt/start"]

