FROM alpine

RUN apk add g++ make python3 libffi-dev libgit2-dev
RUN apk add python3-dev py3-numpy

COPY requirements.txt /root/requirements.txt

RUN pip3 install --upgrade pip
RUN pip3 install -r /root/requirements.txt

COPY . /root

WORKDIR /root

RUN cd /root && make test

ENTRYPOINT ["/bin/sh"]
