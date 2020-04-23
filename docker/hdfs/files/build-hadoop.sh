#!/bin/bash -xe

# Copyright 2020 Crown Copyright
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


test -z "${HADOOP_VERSION}" && HADOOP_VERSION=3.2.1
test -z "${HADOOP_DOWNLOAD_URL}" && HADOOP_DOWNLOAD_URL=https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
test -z "${HADOOP_APPLY_PATCHES}" && HADOOP_APPLY_PATCHES=false
test -z "${PROTOBUF_VERSION}" && PROTOBUF_VERSION=2.5.0

# Allow users to provide their own Hadoop Distribution Tarball
if [ ! -f "./hadoop-${HADOOP_VERSION}.tar.gz" ]; then
	mkdir -p /usr/share/man/man1
	apt -qq update
	apt -qq install -y wget

	# Download official Hadoop Distribution Tarball
	if [ ! -d "/patches/${HADOOP_VERSION}/" ] || [ "${HADOOP_APPLY_PATCHES}" != "true" ]; then
		wget -q ${HADOOP_DOWNLOAD_URL}
	else
		# Build our own HDFS Distribution Tarball with patches applied
		apt -qq install -y \
			automake \
			build-essential \
			cmake \
			g++ \
			git \
			libbz2-dev \
			libsnappy-dev \
			libsasl2-dev \
			libssl-dev \
			libtool \
			libzstd-dev \
			maven \
			openjdk-8-jdk \
			pkg-config \
			yasm \
			zlib1g-dev

		export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64/

		wget -q https://github.com/google/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-${PROTOBUF_VERSION}.tar.gz
		tar -xf protobuf-${PROTOBUF_VERSION}.tar.gz
		cd protobuf-${PROTOBUF_VERSION}
		./configure --prefix=/opt/protobuf/
		make
		make install
		cd ..
		rm -rf protobuf-${PROTOBUF_VERSION}.tar.gz protobuf-${PROTOBUF_VERSION}/
		export PROTOBUF_HOME=/opt/protobuf
		export PATH=${PROTOBUF_HOME}/bin:${PATH}

		git clone https://github.com/01org/isa-l.git
		cd isa-l
		./autogen.sh
		./configure
		make
		make install
		cd ..
		rm -rf isa-l/

		git clone https://github.com/apache/hadoop.git
		cd hadoop
		git checkout rel/release-${HADOOP_VERSION}

		for patch in /patches/${HADOOP_VERSION}/*.patch; do
			git apply $patch
		done

		mvn install \
			-P dist,native \
			-Dtar \
			-Drequire.bzip2 \
			-Drequire.snappy \
			-Drequire.zstd \
			-Drequire.openssl \
			-Drequire.isal \
			-Disal.prefix=/usr \
			-Disal.lib=/usr/lib \
			-Dbundle.isal=true \
			-DskipTests

		mv hadoop-dist/target/hadoop-${HADOOP_VERSION}.tar.gz ../
		cd ..
	fi
fi

tar -xf ./hadoop-${HADOOP_VERSION}.tar.gz

for dir in \
	share/doc \
	share/hadoop/client \
	share/hadoop/mapreduce \
	share/hadoop/tools \
	share/hadoop/yarn \
; do
	[ -d "./hadoop-${HADOOP_VERSION}/${dir}" ] && rm -rf ./hadoop-${HADOOP_VERSION}/${dir}/*
done
