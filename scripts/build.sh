#!/usr/bin/env bash
LICO_IMAGE=openlico:7.2.0

function usage() {

  cat <<-EOF
        Build OpenLiCO Docker Image
        Usage: $0 [OPTIONS]
            build.sh --genSslCert
            build.sh --no-cache --image [name:tag]
            build.sh --npm-registry [npmRegistery] --pypi-url [pypiUrl]

        Options:
            --help             Print the help info
            --genSslCert       Generate nginx ssl certification
            --image            Name and tag of LiCO image: name:tag, default to openlico:7.2.0
            --no-cache         Do not use cache when building the LiCO image
            --npm-registry     Use npm registry to accelerate building web portal, such as <https://registry.npm.taobao.org/>
            --pypi-url         Use pypi url to accelerate install python package, such as<https://pypi.tuna.tsinghua.edu.cn/simple>

EOF
  exit 1
}

function generateSslCert() {
  echo "Generate the nginx ssl certification....."
  mkdir -p nginx/ssl/
  pushd nginx/ssl/
    openssl dhparam -out dhparam.pem 2048
    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -out server.csr -subj "/C=CN/ST=Shanghai/L=Shanghai/O=LiCO/OU=ISG/CN=lenovo.com"
    openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt
  popd
  echo "Generate the nginx ssl certification finished!"
}


 while [[ $# -gt 0 ]]
  do
    key="$1"
    case $key in
        --genSslCert)
          generateSslCert
          exit 0
          ;;
        --image)
          lico_image=$2
          shift
          ;;
         --no-cache)
         enable_no_cache="$key"
          ;;
        --npm-registry)
          npm_registry="$2"
          shift
          ;;
        --pypi-url)
          pypi_url="$2"
          shift
          ;;
        *)
          usage
          ;;
    esac
    shift
  done

 echo "Start build openlico image......"


  if [ -z ${lico_image} ]; then
      lico_image=$LICO_IMAGE
  fi
  if [ $enable_no_cache ]; then
      no_cache="--no-cache"
  fi

  if [ -z ${pypi_url} ]; then
    pypi_url="https://pypi.org/simple"
  fi

  if [ -z ${npm_registry} ]; then
     npm_registry="https://registry.npmjs.org/"
  fi

  docker run -v $PWD/openlico-portal:/openlico-portal -e npm_registry=$npm_registry node:16.19.1-alpine3.16 sh -c "cd openlico-portal &&npm config set registry ${npm_registry} && npm install && npm run build"
  mkdir -p njs/rpmbuild
  \cp openlico-docker/nginx/nginx-mod-njs.spec  njs/
  docker run -v $PWD/njs/rpmbuild:/root/rpmbuild -v $PWD/njs/nginx-mod-njs.spec:/root/nginx-mod-njs.spec rockylinux:8.6.20227707 sh -c "dnf install -y wget which rpm-build gcc libxslt-devel \
         && dnf --enablerepo=devel install -y libedit-devel && dnf module enable -y nginx:1.20 \
         && dnf install -y  nginx-mod-devel &&  mkdir -p  /root/rpmbuild/SOURCES && wget http://hg.nginx.org/njs/archive/0.8.0.tar.gz -O /root/rpmbuild/SOURCES/njs-0.8.0.tar.gz \
         && cd /root && rpmbuild -ba nginx-mod-njs.spec"

  docker build $no_cache --build-arg npm_registry=$npm_registry --build-arg pypi_url=$pypi_url -f Dockerfile -t ${lico_image} .
    if [ $? -ne 0 ]; then
    echo "Build openlico image failed"
    exit 1
  fi

  echo "Build openlico image finished!"