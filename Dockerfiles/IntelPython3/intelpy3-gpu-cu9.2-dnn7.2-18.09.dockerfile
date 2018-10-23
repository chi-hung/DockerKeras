#######################################################################################################################
#
# Dockerfile for:
#   * Intel® Distribution for Python (Python3), which includes accelerated NumPy, SciPy and scikit-learn.
#     More info:
#       * https://software.intel.com/en-us/articles/intel-optimized-packages-for-the-intel-distribution-for-python
#       * https://software.intel.com/en-us/articles/installing-intel-free-libs-and-python-apt-repo
#   * CUDA9.2 + cuDNN7.2 + NCCL2.2
#
# This Dockerfile creates an image that our GPU-enabled TensorFlow & MXNet images will inherit.
#
#######################################################################################################################
#
# Software License Agreement
#   If you use the docker image built from this Dockerfile, it means 
#   you accept the following agreements:
#     * Intel® Distribution for Python:
#         https://software.intel.com/en-us/articles/end-user-license-agreement
#     * NVIDIA cuDNN:
#         https://docs.nvidia.com/deeplearning/sdk/cudnn-sla/index.html
#     * NVIDIA NCCL:
#         https://docs.nvidia.com/deeplearning/sdk/nccl-sla/index.html
#
#######################################################################################################################
FROM nvidia/cuda:9.2-cudnn7-devel-ubuntu18.04
LABEL maintainer="Chi-Hung Weng <wengchihung@gmail.com>"

# Install some useful packages.
RUN apt update && apt install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        libcurl4-openssl-dev \
        libfreetype6-dev \
        libpng-dev \
        libzmq3-dev \
        pkg-config \
        rsync \
        software-properties-common \
        unzip \
        zip \
        zlib1g-dev \
        openjdk-8-jdk \
        openjdk-8-jre-headless \
        wget \
        qt4-default \
        apt-utils \
        cmake \
        libgtk2.0-dev \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libtbb2 \
        libtbb-dev \
        libjpeg-dev \
        libtiff-dev \
        libdc1394-22-dev \
        unixodbc \
        unixodbc-dev \
        graphviz \
        htop \
        vim && \
        apt clean && \
        rm -rf /var/lib/apt/lists/*

# Install "Intel® Distribution for Python".
WORKDIR /tmp
RUN wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB && \
    apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB && \
    wget https://apt.repos.intel.com/setup/intelproducts.list -O /etc/apt/sources.list.d/intelproducts.list && \
    apt update && apt install -y --no-install-recommends intelpython3 && \
    rm GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB

# To save space, non-necessary package folders are removed (except for OpenMP).
WORKDIR /opt/intel/intelpython3/pkgs
RUN mv /opt/intel/intelpython3/pkgs/opencv-* /tmp && \
    rm -rf * && \
    mv /tmp/opencv-* .

# Set up env variables (Intel® Distribution for Python).
ENV PATH=/opt/intel/intelpython3/bin:${PATH} \
    LD_LIBRARY_PATH=/opt/intel/intelpython3/lib:${LD_LIBRARY_PATH} \
    C_INCLUDE_PATH=/opt/intel/intelpython3/include:${C_INCLUDE_PATH}

# # Update env variables of Intel MPI.
# RUN { printf 'source /opt/intel/intelpython3/bin/mpivars.sh release_mt\n'; cat /etc/bash.bashrc; } >/etc/bash.bashrc.new && \
#     mv /etc/bash.bashrc.new /etc/bash.bashrc

# Install/upgrade/remove Python3 packages:
#   1. Install Dask (for efficient multi-core parallelism). More info: 
#       * https://software.intel.com/en-us/blogs/2016/04/04/unleash-parallel-performance-of-python-programs
#       * http://conference.scipy.org/proceedings/scipy2016/pdfs/anton_malakhov.pdf
#   2. Also, some useful packages are to be installed or upgraded (for image visualization/augmentation, etc).
#   3. GPU-enabled TensorFlow images, etc, will be constructed based on this image. Hence, to avoid conflits,
#      we'll remove Intel's pre-built TensorFlow that is built for CPU only. 
RUN pip --no-cache-dir install "dask[complete]" \
                               seaborn \
                               bokeh \
                               autograd \
                               mlxtend \
                               watermark \
                               pydot-ng \
                               tqdm \
                               oauth2client \
                               pygsheets \
                               tables \
                               pydicom \
                               imageio \
                               bs4 \
                               statsmodels \
                               pyodbc \
                               SQLAlchemy && \
    pip --no-cache-dir install git+https://github.com/aleju/imgaug && \
    pip --no-cache-dir install --upgrade --upgrade-strategy only-if-needed h5py && \
    pip uninstall -y tensorflow && \
    rm -rf /tmp/pip* && \
    rm -rf /root/.cache

# Configuring Jupyter Notebook.
WORKDIR /root/.jupyter
RUN wget https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/tools/docker/jupyter_notebook_config.py
# Jupyter has issues with being run directly:
#   https://github.com/ipython/ipython/issues/7062
# We just add a little wrapper script.
WORKDIR /
RUN wget https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/tools/docker/run_jupyter.sh && \
    chmod +x run_jupyter.sh

# Add the "ipyrun" command. It executes the given notebook & transform it into a HTML file.
RUN printf '#!/bin/bash\njupyter nbconvert --ExecutePreprocessor.timeout=None \
                                           --allow-errors \
                                           --to html \
                                           --execute $1' > /sbin/ipyrun && \
    chmod +x /sbin/ipyrun

# Shorten "nvidia-smi" as "smi" ; shorten "watch -n 1 nvidia-smi" as "wsmi".
RUN { printf 'alias smi="nvidia-smi"\nalias wsmi="watch -n 1 nvidia-smi"\n'; cat /etc/bash.bashrc; } >/etc/bash.bashrc.new && \
    mv /etc/bash.bashrc.new /etc/bash.bashrc

# Expose port 8888 for Jupyter.
EXPOSE 8888

# Upgrade Jupyter Notebook.
RUN pip --no-cache-dir install --upgrade notebook && \
    rm -rf /root/.cache

# Using UTF-8 for the environment.
ENV LANG=C.UTF-8

WORKDIR /workspace
# If no command is given, run jupyter notebook.
CMD ["/run_jupyter.sh", "--allow-root"]