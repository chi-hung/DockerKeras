FROM nvidia/cuda:9.0-cudnn7-devel-ubuntu16.04

MAINTAINER Chi-Hung Weng <wengchihung@gmail.com>

ARG THEANO_VER=rel-1.0.1
ARG LIBGPUARRAY_VER=v0.7.5

RUN apt update && apt install -y --no-install-recommends \
        build-essential \
        curl \
        wget \
        git \
        ca-certificates \
        cmake \
        python \
        python3-dev \
        python3-setuptools \
        python3-nose \
        python3-mako \
        libopenblas-dev \
        libpq-dev \
        libxml2-dev \
        libxslt1-dev \
        libldap2-dev \
        libsasl2-dev \
        libffi-dev \
        libglib2.0 \
        libsm6 \
        libxrender-dev \
        libxext-dev \
        && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Get pip for Python3.
RUN curl -fSsL -O https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py

# Install some useful and deep-learning-related packages for Python3.
RUN pip3 --no-cache-dir install \
         h5py==2.7.0 \
         jupyter \
         matplotlib \
         seaborn \
         bokeh \
         numpy==1.13.3 \
         scipy \
         pandas \
         sklearn \
         scikit-image \
         autograd \
         mlxtend \
         graphviz \
         cython \
         opencv-contrib-python

# Obtain libgpuarray  & pygpu.
RUN git clone https://github.com/Theano/libgpuarray.git /opt/libgpuarray && \
    git -C /opt/libgpuarray checkout ${LIBGPUARRAY_VER}

WORKDIR /opt/libgpuarray

# Build and Install libgpuarray & pygpu.
RUN mkdir Build && \
    cd Build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make && \
    make install && \
    cd .. && \
    python3 setup.py build && \
    python3 setup.py install && \
    ldconfig

# Obtain Theano
RUN git clone git://github.com/Theano/Theano.git /opt/theano && \
    git -C /opt/theano checkout $THEANO_VER

WORKDIR /opt/theano

# Build and Install Theano
RUN python3 setup.py build && \
    python3 setup.py install && \
    cd .. && \
    pip3 install Theano

ENV THEANO_FLAGS 'device=cuda,floatX=float32'
# FP32 is used by default. You can always reset this flag.

# Install Keras.
RUN pip3 install keras

# Tell Keras to use Theano as its backend.
RUN mkdir /root/.keras && \
    wget -O /root/.keras/keras.json https://raw.githubusercontent.com/chi-hung/DockerbuildsKeras/master/keras.json && \
    sed -i -e 's/cntk/theano/g' /root/.keras/keras.json

# Set up our notebook config.
RUN mkdir /root/.jupyter && \
    cd /root/.jupyter && \
    wget https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/tools/docker/jupyter_notebook_config.py

# Jupyter has issues with being run directly:
#   https://github.com/ipython/ipython/issues/7062
# We just add a little wrapper script.
RUN cd / && \
    wget https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/tools/docker/run_jupyter.sh && \
    chmod +x run_jupyter.sh

# Add a sample notebook.
RUN mkdir /notebooks && \
    wget -O /notebooks/MNISTDemoKeras.ipynb https://raw.githubusercontent.com/chi-hung/PythonTutorial/master/code_examples/KerasMNISTDemo.ipynb
WORKDIR /notebooks

CMD ["/run_jupyter.sh", "--allow-root"]
#RUN ["/bin/bash"]