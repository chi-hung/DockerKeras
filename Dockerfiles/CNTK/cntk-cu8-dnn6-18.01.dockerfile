FROM microsoft/cntk:2.2-gpu-python3.5-cuda8.0-cudnn6.0

MAINTAINER Chi-Hung Weng <wengchihung@gmail.com>

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        libgtk2.0-0 \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV source_cntk "source /cntk/activate-cntk"

# Install OpenCV 3 and Bokeh.
RUN /bin/bash -c "${source_cntk} && conda install -y -c menpo opencv3 && \
                                    conda install -y bokeh && \
                                    conda install -y -c anaconda keras"

# Obtain/Upgrade some useful packages.
RUN /bin/bash -c "${source_cntk} && conda update -y scipy \
                                                    numpy \
                                                    seaborn \
                                                    matplotlib \
                                                    pandas \
                                                    scikit-image \
                                                    scikit-learn \
                                                    jupyter"

# Tell Keras to use CNTK as its backend.
RUN mkdir /root/.keras && \
    wget -O /root/.keras/keras.json https://raw.githubusercontent.com/chi-hung/DockerbuildsKeras/master/keras-cntk.json

# Set up our notebook config.
RUN mkdir /root/.jupyter && \
    cd /root/.jupyter && \
    wget https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/tools/docker/jupyter_notebook_config.py

# Jupyter has issues with being run directly:
#   https://github.com/ipython/ipython/issues/7062
# We just add a little wrapper script.
RUN echo 'source /cntk/activate-cntk && jupyter notebook "$@"' > /root/run_jupyter.sh

RUN mkdir /notebooks && \
    wget -O /notebooks/MNISTDemoKeras.ipynb https://raw.githubusercontent.com/chi-hung/PythonTutorial/master/code_examples/KerasMNISTDemo.ipynb
WORKDIR /notebooks

# IPython
EXPOSE 8888

ENTRYPOINT ["/bin/bash"]
CMD ["/root/run_jupyter.sh", "--allow-root"]
