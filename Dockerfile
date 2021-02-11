FROM jeanblanchard/alpine-glibc

# Build command: docker build --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') --build-arg VERSION=$(echo -n 3.11.6-;date -u +'%Y%m%d') -t repo/lazylibrarian-calibre .
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Minimal LazyLibrarian with Calibre:- ${VERSION} Build-date:- ${BUILD_DATE}"

ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/opt/calibre/lib
ENV PATH $PATH:/opt/calibre/bin
ENV CALIBRE_INSTALLER_SOURCE_CODE_URL https://raw.githubusercontent.com/kovidgoyal/calibre/master/setup/linux-installer.py
ENV CALIBRE_CONFIG_DIRECTORY="/config/calibre/"
ENV CALIBRE_TEMP_DIR="/config/calibre/tmp/"
ENV CALIBRE_CACHE_DIRECTORY="/config/cache/calibre/"

# install build packages
# qt5-qtbase-x11: build calibre
# xdg-utils: build calibre
# g++: build libunrar
# make: build libunrar
RUN \
 apk update && \
 apk add --no-cache --upgrade --virtual=build-dependencies \
        qt5-qtbase-x11 \
        xdg-utils \
        g++ \
        make && \

# install runtime packages
# ca-certificates: LL safe downloading
# ghostscript: LL image manipulation
# git: LL self-update (optional)
# libstdc++: calibre
# mesa-gl: calibre
# py3-webencodings: LL get info on random web files
 apk add --no-cache --upgrade \
        ca-certificates \
        ghostscript \
        git \
        libstdc++ \
        mesa-gl \
        py3-webencodings && \

 # build calibre
 echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
 wget -O- ${CALIBRE_INSTALLER_SOURCE_CODE_URL} | python3 -c "import sys; main=lambda:sys.stderr.write('Download failed\n'); exec(sys.stdin.read()); main(install_dir='/opt', isolated=True)" && \

 # Remove unused QT code (non-exhaustive list)
 rm /opt/calibre/lib/libQt5WebEngineCore.so.5 && \

 # LL Web Parsing
 apk add py3-html5lib --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ && \

# build unrarlib
 rar_ver=$(apk info unrar | grep unrar- | cut -d "-" -f2 | head -1) && \
 mkdir -p \
        /tmp/unrar && \
 wget -O \
        /tmp/unrar-src.tar.gz \
        "https://www.rarlab.com/rar/unrarsrc-5.8.5.tar.gz" && \
 tar xf \
        /tmp/unrar-src.tar.gz -C \
        /tmp/unrar --strip-components=1 && \
 cd /tmp/unrar && \
 make lib && \
 make install-lib && \
 rm /usr/lib/libunrar.a && \

 # install app
 git clone --depth 1 https://gitlab.com/LazyLibrarian/LazyLibrarian.git /app/lazylibrarian && \

 # cleanup
 apk del --purge \
        build-dependencies && \
 rm -rf \
        /tmp/* && \
 rm -rf \
        /tmp/calibre-installer-cache && \
 rm -rf \
        glibc.apk glibc-bin.apk /var/cache/apk/*

# Apprise notification plugin to LL (optional)
RUN pip3 install apprise

# add local files
COPY root/ /

# ports and volumes
EXPOSE 5299
VOLUME /config /books /audiobooks /magazines /comics /downloads
ENTRYPOINT "/usr/bin/python3" "/app/lazylibrarian/LazyLibrarian.py" "--datadir" "/config" "--nolaunch"

