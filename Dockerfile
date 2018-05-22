FROM amazonlinux:latest

MAINTAINER Gamma Gao 

# install tools
RUN yum -y update ;\
    yum -y install epel-release python-pip git openssh-server openssh-clients make wget sudo vim java-1.8.0-openjdk; \
    yum clean all  

# install go
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
ARG GOFILE=go1.10.2.linux-amd64.tar.gz
ARG GOURL=https://storage.googleapis.com/golang/$GOFILE
ARG GOSHA256=4b677d698c65370afa33757b6954ade60347aaca310ea92a63ed717d7cb0c2ff
RUN set -eux &&\
    curl -OL $GOURL \
    && echo "$GOSHA256  $GOFILE" | sha256sum -c - \
    && tar -C /usr/local -xzf $GOFILE \
    && rm $GOFILE \
    && mkdir -p "$GOPATH/src" "$GOPATH/bin" \
    && chmod -R 777 "$GOPATH"

# install go packages 
RUN go get github.com/fvbock/endless \
    github.com/gin-gonic/gin \
    github.com/jmoiron/sqlx \
    github.com/sirupsen/logrus \
    github.com/go-sql-driver/mysql \
    github.com/aws/aws-sdk-go \
    github.com/braintree/manners \
    github.com/xeipuuv/gojsonschema \
    github.com/RackSec/srslog \
    github.com/satori/go.uuid

# create user jenkinsbuild
RUN set -eux &&\ 
    useradd --create-home --no-log-init --shell /bin/bash jenkinsbuild \
    && echo 'jenkinsbuild:jenkinsbuild' | chpasswd \
    && groupadd docker \
    && usermod -aG docker jenkinsbuild \
    && usermod -aG root jenkinsbuild \
    && ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key \
    && ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key  \
    && sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config \
    && sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config \
    && echo 'AllowUsers jenkinsbuild' >> /etc/ssh/sshd_config \
    && mkdir /var/run/sshd \
    && sed -i 's/root	ALL=(ALL) 	ALL/root	ALL=(ALL) 	ALL\njenkinsbuild	ALL=(ALL) 	NOPASSWD: ALL/g' /etc/sudoers \
    && echo 'export GOROOT=/usr/local/go' >> /etc/profile \
    && echo 'export GOBIN=$GOROOT/bin' >> /etc/profile \
    && echo 'export PATH=$PATH:$GOBIN' >> /etc/profile \
    && echo 'export GOPATH=/go' >> /etc/profile \
    && echo 'source /etc/profile' >> /home/jenkinsbuild/.bashrc 

# install docker client
ARG DOCKERURL=https://download.docker.com/linux/static/stable/x86_64/docker-18.03.0-ce.tgz
ARG DOCKERSHA256=e5dff6245172081dbf14285dafe4dede761f8bc1750310156b89928dbf56a9ee
RUN set -eux &&\
    curl -fSL "$DOCKERURL" -o docker.tgz \
    && echo "$DOCKERSHA256 *docker.tgz" | sha256sum -c - \
    && tar -xzvf docker.tgz \
    && mv docker/* /usr/local/bin/ \
    && rmdir docker \
    && rm docker.tgz \
    && chmod +x /usr/local/bin/docker 

WORKDIR /home/jenkinsbuild/ci-jenkins

# install entrypoint
COPY dind-entrypoint.sh /usr/local/bin/ 
RUN set -eux &&\
    chown -R jenkinsbuild:jenkinsbuild /home/jenkinsbuild/ci-jenkins \
    && chmod +x /usr/local/bin/dind-entrypoint.sh

EXPOSE 22 

ENTRYPOINT ["dind-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
