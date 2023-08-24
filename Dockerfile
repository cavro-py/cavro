FROM alpine

RUN apk update
RUN apk add g++ make python3 libffi-dev libgit2-dev snappy-dev
RUN apk add python3-dev py3-numpy py3-pygit2 py3-pip
RUN apk add git

COPY requirements.txt /root/requirements.txt

RUN pip3 install --upgrade pip
RUN pip3 install python-snappy

COPY . /root

WORKDIR /root

RUN mkdir /root/wheels
RUN cd /root && pip wheel . --no-deps -w /root/wheels

RUN pip3 install $(echo /root/wheels/*.whl)[test]
RUN pip3 install -r /root/benchmark/requirements.txt

ENTRYPOINT ["/bin/sh"]
