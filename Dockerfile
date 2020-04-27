FROM alpine
RUN echo 'http://nl.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories
RUN apk update
RUN apk add g++ make python3 libffi-dev libgit2-dev
RUN apk add python3-dev py3-numpy py3-pygit2
RUN apk add git

COPY requirements.txt /root/requirements.txt

RUN pip3 install --upgrade pip
RUN pip3 install -r /root/requirements.txt
RUN pip3 install python-snappy

COPY . /root

WORKDIR /root

RUN cd /root && make test

RUN pip3 install -r /root/benchmark/requirements.txt

ENTRYPOINT ["/bin/sh"]
