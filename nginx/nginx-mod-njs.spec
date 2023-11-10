%global nginx_modname njs
%global origname nginx-module-%{nginx_modname}

Name:           nginx-mod-njs
Version:        0.8.0
Release:        el8.7.1
Summary:        NGINX module for NGINX Javascript

License:        BSD-2-Clause
URL:            https://nginx.org/en/docs/njs/
Source0:        %{nginx_modname}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  nginx-mod-devel
BuildRequires:  libxslt-devel
BuildRequires:  zlib-devel
BuildRequires:  pcre-devel
BuildRequires:  pcre2-devel
BuildRequires:  libedit-devel
BuildRequires:  openssl-devel


%description
%{summary}.

%package -n njs
Summary: Shell toolkit for NGINX Javascript

%description -n njs
NGINX module for NGINX Javascript: Shell toolkits.

%package -n nginx-mod-http-js
Summary: NGINX module for NGINX Javascript: http module

%description -n nginx-mod-http-js
NGINX module for NGINX Javascript: http module.

%package -n nginx-mod-stream-js
Summary: NGINX module for NGINX Javascript: stream module

Requires: nginx-mod-stream = %{_nginx_abiversion}

%description -n nginx-mod-stream-js
NGINX module for NGINX Javascript: stream module.

%prep
%autosetup -n %{nginx_modname}-%{version}

%build
pushd nginx
%nginx_modconfigure --with-stream=dynamic
%nginx_modbuild
popd

./configure
make njs

%install
install -Dp -m 0755 build/njs %{buildroot}%{_bindir}/njs

pushd nginx/%{_vpath_builddir}
install -dm 0755 %{buildroot}%{nginx_moddir}
install -pm 0755 ngx_http_js_module.so %{buildroot}%{nginx_moddir}
install -pm 0755 ngx_stream_js_module.so %{buildroot}%{nginx_moddir}
install -dm 0755 %{buildroot}%{nginx_modconfdir}
echo 'load_module "%{nginx_moddir}/ngx_http_js_module.so";' \
    > %{buildroot}%{nginx_modconfdir}/mod-http-js.conf
popd

%files -n njs
%license LICENSE
%doc README
%{_bindir}/njs

%files -n nginx-mod-http-js
%license LICENSE
%doc README
%{nginx_moddir}/ngx_http_js_module.so
%{nginx_modconfdir}/mod-http-js.conf

%files -n nginx-mod-stream-js
%license LICENSE
%doc README
%{nginx_moddir}/ngx_stream_js_module.so

%changelog