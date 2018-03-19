FROM maven:3.5.3-jdk-8-alpine as builder

ARG HADOOP_VERSION=3.0.0
ARG PROTOBUF_VERSION=2.5.0
ENV HADOOP_HOME=/hadoop
RUN apk --no-cache add bash \
    && mkdir -p $HADOOP_HOME \
    && apk --no-cache add --virtual .build-dependencies \
    curl \
    tar \
    build-base \
    automake \
    autoconf \
    libtool \
    cmake \
    snappy-dev \
    zlib-dev \
    libbz2 \
    bzip2-dev \
    zstd-dev \
    jansson-dev \
    libressl-dev \
    fts-dev \
    libtirpc-dev \
    fuse-dev \
    && echo "Downloading source for protoc ${PROTOBUF_VERSION}." \
    && curl -sL --retry 3 "https://github.com/google/protobuf/archive/v${PROTOBUF_VERSION}.tar.gz" | \
    tar -xz --strip 1 -C /tmp \
    && echo "Downloading protoc ${PROTOBUF_VERSION} autogen.sh update" \
    && curl -sL -o /tmp/autogen.sh --retry 3 "https://raw.githubusercontent.com/google/protobuf/master/autogen.sh" \
    && cd /tmp \
    && chmod +x autogen.sh \
    && sh autogen.sh \
    && ./configure --prefix=/usr \
    && make \
    && make install \
    && ldconfig ./ \
    && echo "Downloading source for Hadoop version ${HADOOP_VERSION}." \
    && curl -sL --retry 3 "http://mirror.vorboss.net/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}-src.tar.gz" | \
    tar -xz --strip 1 -C $HADOOP_HOME/

#There is an issue with the pom.xml file in the current hadoop distribution, so copy in local fix before building
COPY pom.xml $HADOOP_HOME

RUN cd $HADOOP_HOME \
    && echo "Packaging Hadoop version ${HADOOP_VERSION} without native library support." \
    && mvn clean package -Pdist,native -Drequire.snappy -Drequire.zstd -DskipTests -DskipDocs -Dtar -Dmaven.javadoc.skip=true

FROM openjdk:8-jre-alpine3.7 as base

RUN mkdir -p /hadoop
COPY --from=builder /hadoop/hadoop-dist/target/hadoop-3.0.0/ /hadoop/
