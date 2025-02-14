FROM ruby:3.3.5-bookworm AS builder

ARG NAROU_VERSION=3.9.1
ARG AOZORAEPUB3_VERSION=1.1.1b26Q
ARG AOZORAEPUB3_FILE=AozoraEpub3-${AOZORAEPUB3_VERSION}

RUN apt update && \
    curl -LO https://download.java.net/java/GA/jdk21/fd2272bbf8e04c3dbaee13770090416c/35/GPL/openjdk-21_linux-x64_bin.tar.gz && \
    tar zxf openjdk-21_linux-x64_bin.tar.gz && mv jdk-21 /usr/local/jdk-21 && \
    export JAVA_HOME=/usr/local/jdk-21 && \
    export PATH=$PATH:$JAVA_HOME/bin && \
    jlink --no-header-files --no-man-pages --compress=2 --add-modules java.base,java.datatransfer,java.desktop --output /opt/jre && \
    gem install narou -v ${NAROU_VERSION} --no-document && \
    wget https://github.com/kyukyunyorituryo/AozoraEpub3/releases/download/v${AOZORAEPUB3_VERSION}/${AOZORAEPUB3_FILE}.zip && \
    unzip ${AOZORAEPUB3_FILE} -d /opt/aozoraepub3

FROM ruby:3.3.5-slim-bookworm

ARG UID=3007
ARG GID=3003

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /opt/aozoraepub3 /opt/aozoraepub3
COPY --from=builder /lib/x86_64-linux-gnu/libjpeg* /lib/x86_64-linux-gnu/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libjpeg* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /opt/jre /opt/jre
COPY init.sh /usr/local/bin

# Modify the WebSocket server to accept all origins
RUN sed -i "s/server\.accepted_domains = \[.*\]/server.accepted_domains = [\"*\"]/" /usr/local/bundle/gems/narou-3.9.1/lib/web/web-socket-ruby/lib/web_socket.rb

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
