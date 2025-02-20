FROM ruby:3.4.2-bookworm AS builder

ARG NAROU_VERSION=3.9.1
ARG AOZORAEPUB3_VERSION=1.1.1b30Q
ARG AOZORAEPUB3_FILE=AozoraEpub3-${AOZORAEPUB3_VERSION}

RUN apt update && \
    curl -LO https://download.java.net/java/GA/jdk21/fd2272bbf8e04c3dbaee13770090416c/35/GPL/openjdk-21_linux-x64_bin.tar.gz && \
    tar zxf openjdk-21_linux-x64_bin.tar.gz && mv jdk-21 /usr/local/jdk-21 && \
    export JAVA_HOME=/usr/local/jdk-21 && \
    export PATH=$PATH:$JAVA_HOME/bin && \
    jlink --no-header-files --no-man-pages --compress=2 --add-modules java.base,java.datatransfer,java.desktop --output /opt/jre && \
    # fix - tilt 2.5.0+ won't work with narou.rb #
    gem install tilt -v 2.4.0 --no-document && \
    gem install narou -v ${NAROU_VERSION} --no-document && \
    wget https://github.com/kyukyunyorituryo/AozoraEpub3/releases/download/v${AOZORAEPUB3_VERSION}/${AOZORAEPUB3_FILE}.zip && \
    unzip ${AOZORAEPUB3_FILE} -d /opt/aozoraepub3

# kindlegen download #
#RUN curl -LO https://archive.org/download/kindlegen_linux_2_6_i386_v2_9/kindlegen_linux_2.6_i386_v2_9.tar.gz && \
#	tar zxf kindlegen_linux_2.6_i386_v2_9.tar.gz && mv kindlegen /opt/aozoraepub3
    
# Dirty Fix for using Title instead of ID in Mails #
COPY pony.rb /usr/local/bundle/gems/pony-1.13.1/lib/
COPY mailer.rb /usr/local/bundle/gems/narou-${NAROU_VERSION}/lib/

FROM ruby:3.4.2-slim-bookworm

# Edit to you own UID/GID #
ARG UID=3007
ARG GID=3003

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /opt/aozoraepub3 /opt/aozoraepub3
COPY --from=builder /lib/x86_64-linux-gnu/libjpeg* /lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libjpeg* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /opt/jre /opt/jre
COPY init.sh /usr/local/bin

ENV JAVA_HOME=/opt/jre
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN groupadd -g ${GID} narou && \
    adduser narou --shell /bin/bash --uid ${UID} --gid ${GID} && \
    chmod +x /usr/local/bin/init.sh

USER narou

WORKDIR /home/narou/novel

EXPOSE 33000-33001

ENTRYPOINT ["init.sh"]
CMD ["narou", "web", "-np", "33000"]
