FROM ubuntu:18.04

RUN sed -i.bak -e "s%http://archive.ubuntu.com/ubuntu/%http://ftp.iij.ad.jp/pub/linux/ubuntu/archive/%g" /etc/apt/sources.list
RUN apt-get update -y && apt-get upgrade -y 

# Basic commnads
RUN apt-get install -y sudo vim git cmake tmux xsel debootstrap \
    gcc build-essential pkg-config libpq-dev libssl-dev openssl \
    iputils-ping net-tools traceroute

RUN apt-get install -y nodejs npm

# For Flutter
RUN apt-get install -y clang ninja-build libgtk-3-dev unzip curl

# For Wayland/Weston
RUN apt-get install -y libgles2-mesa-dev libxml2-dev libinput-dev libpam0g-dev libgbm-dev libva-dev liblcms2-dev \
    libxcb-xkb-dev libcolord-dev python3-pip
RUN pip3 install meson

# Remove packages
RUN apt-get autoremove -y libreoffice* thunderbird firefox gnome-games rhythmbox gnome-mines aisleriot byobu \
    cheese gnome-mahjongg gnome-sudoku gnome-calendar
RUN apt-get autoclean && apt-get clean


ARG DOCKER_UID=9001
ARG DOCKER_GID=9001
ARG DOCKER_USER=user
ARG DOCKER_PASSWORD=user

RUN groupadd --gid ${DOCKER_GID} ${DOCKER_USER}
RUN useradd --create-home --uid ${DOCKER_UID} --gid ${DOCKER_GID} --groups sudo --shell /bin/bash ${DOCKER_USER} \
&& echo ${DOCKER_USER}:${DOCKER_PASSWORD} | chpasswd

# Wayland/Weston
RUN cd /root && \
    git clone git://anongit.freedesktop.org/wayland/wayland-protocols && \
    cd wayland-protocols/ && \
    ./autogen.sh --prefix=/usr/local && \ 
    make install

RUN cd /root && \
    git clone https://gitlab.freedesktop.org/wayland/wayland.git  && \
    cd wayland && \
    ./autogen.sh --prefix=/usr/local --disable-documentation && \
    make && \
    make install 

RUN cd /root && \
    git clone https://github.com/wayland-project/weston.git -b 7.0 && \
    cd weston && \
    meson build/ --prefix=/usr/local -Dimage-jpeg=false -Dimage-webp=false -Dlauncher-logind=false -Dbackend-rdp=false -Dxwayland=false \
    -Dsystemd=false -Dremoting=false -Dpipewire=false -Dsimple-dmabuf-drm=auto && \
    ninja -C build/ install && \
    ldconfig

RUN cd /root && \
    git clone https://github.com/GENIVI/dlt-daemon.git -b v2.18.5 && \
    cd dlt-daemon/ && \
    apt-get install -y cmake zlib1g-dev libdbus-glib-1-dev && \
    mkdir build && \
    cd build/ && \
    cmake .. && \
    make && \
    make install && \
    ldconfig

COPY ./settings/110.patch /root
RUN cd /root && \
    apt-get install -y libpixman-1-0 && \
    git clone https://github.com/GENIVI/wayland-ivi-extension.git && \
    cd wayland-ivi-extension/ && \
    git checkout 9bc63f152c48c5078bca8353c8d8f30293603257 && \
    git config --local user.email "you@example.com" && \
    git config --local user.name "Your Name" && \
    git am /root/110.patch  && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && \
    make install && \
    ldconfig

WORKDIR /root

# Enable wayland id-agent
COPY ./settings/weston.ini /etc/xdg/weston/weston.ini

# Flutter
RUN mkdir -p /home/${DOCKER_USER}/.local/bin
RUN git clone https://github.com/flutter/flutter
RUN mv flutter /home/${DOCKER_USER}/.local/
ENV PATH $PATH:/home/${DOCKER_USER}/.local/flutter/bin/:/home/${DOCKER_USER}/.local/bin/

COPY ./settings/flutter_init.sh /home/${DOCKER_USER}/.local/bin
RUN chmod +x /home/${DOCKER_USER}/.local/bin/flutter_init.sh 
RUN chown -R ${DOCKER_USER}:${DOCKER_USER} /home/${DOCKER_USER}

#COPY ./script/.bashrc.patch   /tmp
#RUN cat /tmp/.bashrc.patch >> /home/${DOCKER_USER}/.bashrc
#RUN rm -rf /tmp/.bashrc.patch

# For CEF/Chromium
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /root
RUN apt-get install -y curl lsb-release tzdata libgtkglext1-dev wget python3 python3-pip ninja-build xcb-proto python-xcbgen python-setuptools
RUN curl 'https://chromium.googlesource.com/chromium/src/+/master/build/install-build-deps.sh?format=TEXT' \
 | base64 -d > install-build-deps.sh
RUN chmod +x install-build-deps.sh 
RUN ./install-build-deps.sh --no-arm --no-chromeos-fonts --no-nacl --no-prompt

ARG WORK=/root/cef_build/
WORKDIR ${WORK}
RUN git clone https://bitbucket.org/msisov/cef
WORKDIR cef
RUN git checkout origin/wayland_support

RUN cd ${WORK} && \
    cp cef/tools/automate/automate-git.py ./ && \
    python ./automate-git.py --download-dir=. --no-distrib --no-build --url=https://bitbucket.org/msisov/cef  --checkout=bbc875c6c8b5aecc176141a7a88002631ee1bad2

ENV PATH {$PATH}:${WORK}/depot_tools
WORKDIR ${WORK}/chromium/src/cef
ENV GN_DEFINES "is_official_build=true use_allocator=none symbol_level=1 use_cups=false \
use_gnome_keyring=false enable_remoting=false enable_nacl=false use_kerberos=false use_gtk=false \
treat_warnings_as_errors=false ozone_platform_wayland=true ozone_platform_x11=true ozone_platform=wayland \
use_ozone=true use_glib=true use_aura=true ozone_auto_platforms=false dcheck_always_on=false use_xkbcommon=true \
use_system_minigbm=true use_system_libdrm=true"
RUN ./cef_create_projects.sh
WORKDIR ${WORK}/chromium/src
RUN ninja -j16 -C out/Release_GN_x64/ cefsimple
RUN mkdir -p /home/${DOCKER_USER}/.local/cef/
RUN cp out/Release_GN_x64/*.dat /home/${DOCKER_USER}/.local/cef
RUN cp out/Release_GN_x64/*.pak /home/${DOCKER_USER}/.local/cef
RUN cp out/Release_GN_x64/*.bin /home/${DOCKER_USER}/.local/cef
RUN cp out/Release_GN_x64/*.so /home/${DOCKER_USER}/.local/cef
RUN cp -r out/Release_GN_x64/locales /home/${DOCKER_USER}/.local/cef
RUN cp out/Release_GN_x64/cefsimple /home/${DOCKER_USER}/.local/cef
RUN chown -R ${DOCKER_USER}:${DOCKER_USER} /home/${DOCKER_USER}
ENV PATH $PATH:/home/${DOCKER_USER}/.local/cef
RUN echo "/home/${DOCKER_USER}/.local/cef" > /etc/ld.so.conf.d/cef.conf
RUN ldconfig
RUN usermod -aG video user

USER ${DOCKER_USER}
WORKDIR /home/${DOCKER_USER}
