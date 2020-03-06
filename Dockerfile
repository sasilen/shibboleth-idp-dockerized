FROM alpine:latest as temp

ENV jetty_version=9.4.26.v20200117 \
    jetty_hash=31a157c493687e9b7be7366a5dc4ee7ef9cae1663ea279cd9fcf4070d53ef071 \
    idp_version=4.0.0-beta2 \
    idp_hash=a2ecbacc2858fb5eeacba1a8918baf2124f92f83e7c42f3200a0ab14fdd5f439 \
    slf4j_version=1.7.29 \
    slf4j_hash=47b624903c712f9118330ad2fb91d0780f7f666c3f22919d0fc14522c5cad9ea \
    logback_version=1.2.3 \
    logback_classic_hash=fb53f8539e7fcb8f093a56e138112056ec1dc809ebb020b59d8a36a5ebac37e0 \
    logback_core_hash=5946d837fe6f960c02a53eda7a6926ecc3c758bbdd69aa453ee429f858217f22 \
    logback_access_hash=0a4fc8753abe266ea7245e6d9653d6275dc1137cad6ecd1b2612204033d89687 \
    mariadb_version=2.5.4 \
    mariadb_hash=5fafee1aad82be39143b4bfb8915d6c2d73d860938e667db8371183ff3c8500a

ENV JETTY_HOME=/opt/jetty-home \
    JETTY_BASE=/opt/jetty-base \
    JETTY_KEYSTORE_PASSWORD=changeme \
    IDP_HOME=/opt/shibboleth-idp \
    JAVA_HOME=/usr/lib/jvm/default-jvm \
    IDP_SRC=/opt/shibboleth-identity-provider-$idp_version \
    IDP_SCOPE=example.fi \
    IDP_HOST_NAME=testidp.example.fi \
    IDP_ENTITYID=https://testidp.example.fi/idp/shibboleth \
    IDP_KEYSTORE_PASSWORD=changeme \
    IDP_SEALER_PASSWORD=changeme \
    PATH=$PATH:$JRE_HOME/bin

LABEL maintainer="CSCfi"\
      idp.java.version="Alpine - java-11-openjdk-headless" \
      idp.jetty.version=$jetty_version \
      idp.version=$idp_version

RUN apk --no-cache add wget tar openjdk11-jre-headless bash

# JETTY - Download, verify and install with base
RUN wget -q https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/$jetty_version/jetty-distribution-$jetty_version.tar.gz \
    && echo "$jetty_hash  jetty-distribution-$jetty_version.tar.gz" | sha256sum -c - \
    && tar -zxvf jetty-distribution-$jetty_version.tar.gz -C /opt \
    && ln -s /opt/jetty-distribution-$jetty_version/ /opt/jetty-home \
    && rm jetty-distribution-$jetty_version.tar.gz

# JETTY Configure
RUN mkdir -p $JETTY_BASE/modules $JETTY_BASE/lib/ext $JETTY_BASE/lib/logging $JETTY_BASE/resources \
    && cd $JETTY_BASE \
    && touch start.ini \
    && $JAVA_HOME/bin/java -jar ../jetty-home/start.jar --create-startd --add-to-start=http,https,deploy,ext,annotations,jstl,rewrite,ssl,setuid

# Shibboleth IdP - Download, verify hash and install
RUN wget -q https://shibboleth.net/downloads/identity-provider/$idp_version/shibboleth-identity-provider-$idp_version.tar.gz \
    && echo "$idp_hash  shibboleth-identity-provider-$idp_version.tar.gz" | sha256sum -c - \
    && tar -zxvf  shibboleth-identity-provider-$idp_version.tar.gz -C /opt \
    && $IDP_SRC/bin/install.sh \
    -Didp.scope=$IDP_SCOPE \
    -Didp.target.dir=$IDP_HOME \
    -Didp.src.dir=$IDP_SRC \
    -Didp.scope=$IDP_SCOPE \
    -Didp.host.name=$IDP_HOST_NAME \
    -Didp.noprompt=true \
    -Didp.sealer.password=$IDP_SEALER_PASSWORD \
    -Didp.keystore.password=$IDP_KEYSTORE_PASSWORD \
    -Didp.entityID=$IDP_ENTITYID \
    && rm shibboleth-identity-provider-$idp_version.tar.gz

# slf4j - Download, verify and install
RUN wget -q https://repo1.maven.org/maven2/org/slf4j/slf4j-api/$slf4j_version/slf4j-api-$slf4j_version.jar \
    && echo "$slf4j_hash  slf4j-api-$slf4j_version.jar" | sha256sum -c - \
    && mv slf4j-api-$slf4j_version.jar $JETTY_BASE/lib/logging/

# logback_classic - Download verify and install
RUN wget -q https://repo1.maven.org/maven2/ch/qos/logback/logback-classic/$logback_version/logback-classic-$logback_version.jar \
    && echo "$logback_classic_hash  logback-classic-$logback_version.jar" | sha256sum -c - \
    && mv logback-classic-$logback_version.jar $JETTY_BASE/lib/logging/

# logback-core - Download, verify and install
RUN wget -q https://repo1.maven.org/maven2/ch/qos/logback/logback-core/$logback_version/logback-core-$logback_version.jar \
    && echo "$logback_core_hash  logback-core-$logback_version.jar" | sha256sum -c - \
    && mv logback-core-$logback_version.jar $JETTY_BASE/lib/logging/

# logback-access - Download, verify and install
RUN wget -q https://repo1.maven.org/maven2/ch/qos/logback/logback-access/$logback_version/logback-access-$logback_version.jar \
    && echo "$logback_access_hash  logback-access-$logback_version.jar" | sha256sum -c - \
    && mv logback-access-$logback_version.jar $JETTY_BASE/lib/logging/

# mariadb-java-client - Donwload, verify and install
RUN wget -q https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/$mariadb_version/mariadb-java-client-$mariadb_version.jar \
    && echo "$mariadb_hash  mariadb-java-client-$mariadb_version.jar" | sha256sum -c - \
    && mv mariadb-java-client-$mariadb_version.jar $IDP_HOME/edit-webapp/WEB-INF/lib/

COPY opt/jetty-base/ /opt/jetty-base/
COPY opt/shibboleth-idp/ /opt/shibboleth-idp/

# Create new user to run jetty with
RUN addgroup -g 1000 -S jetty && \
    adduser -u 1000 -S jetty -G jetty -s /bin/false

# Set ownerships
RUN mkdir $JETTY_BASE/logs \
    && chown -R root:jetty $JETTY_BASE \
    && chmod -R 550 $JETTY_BASE \
    && chmod -R 550 /opt/shibboleth-idp/bin \
    && chown -R root:jetty /opt \
    && chmod -R 550 /opt

FROM alpine:latest

RUN apk --no-cache add wget tar openjdk11-jre-headless bash

LABEL maintainer="CSCfi"\
    idp.java.version="Alpine - java-11-openjdk-headless" \
    idp.jetty.version=$jetty_version \
    idp.version=$idp_version

COPY bin/ /usr/local/bin/

RUN addgroup -g 1000 -S jetty \
    && adduser -u 1000 -S jetty -G jetty -s /bin/false \
    && chmod 750 /usr/local/bin/run-jetty.sh /usr/local/bin/init-idp.sh

COPY --from=temp /opt/ /opt/

RUN chmod +x /opt/jetty-home/bin/jetty.sh

# Opening 443
EXPOSE 443

#CMD ["run-jetty.sh"]
CMD ["/usr/lib/jvm/default-jvm/bin/java","-jar","/opt/jetty-home/start.jar","jetty.home=/opt/jetty-home","jetty.base=/opt/jetty-base"]
