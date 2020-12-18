ARG CUDA="10.1"


FROM nvidia/cuda:${CUDA}-devel-ubuntu16.04

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# install basics
RUN apt-get update -y \
    && apt-get install -y apt-utils git curl ca-certificates bzip2 cmake tree htop bmon iotop g++ \
    && apt-get install -y libglib2.0-0 libsm6 libxext6 libxrender-dev

# Install Miniconda
RUN curl -so /miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && chmod +x /miniconda.sh \
    && /miniconda.sh -b -p /miniconda \
    && rm /miniconda.sh

ENV PATH=/miniconda/bin:$PATH

# Create a Python 3.6 environment
RUN /miniconda/bin/conda install -y conda-build \
    && /miniconda/bin/conda create -y --name py36 python=3.6.7 \
    && /miniconda/bin/conda clean -ya

ENV CONDA_DEFAULT_ENV=py36
ENV CONDA_PREFIX=/miniconda/envs/$CONDA_DEFAULT_ENV
ENV PATH=$CONDA_PREFIX/bin:$PATH
ENV CONDA_AUTO_UPDATE_CONDA=false

RUN conda install pytorch=1.4.0 torchvision=0.5.0 cudatoolkit=10.1 -c pytorch

# Not available in build phase
# RUN python3 -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.device_count()); assert torch.cuda.is_available(); assert torch.cuda.device_count() >= 1;"

RUN pip install -U setuptools

RUN mkdir /apex
RUN wget -q -O - "https://github.com/NVIDIA/apex/tarball/37cdaf4ad57ab4e7dd9ef13dbed7b29aa939d061" | tar xfz - --strip-components 1 -C /apex/ 
RUN cd /apex && python setup.py install --cuda_ext --cpp_ext
# RUN cd ../ && rm -rf /apex

RUN mkdir /cityscapesScripts
RUN wget -q -O - "https://github.com/mcordts/cityscapesScripts/tarball/ec896c1817db096c402c44a8bafec461ef887b19" | tar xfz - --strip-components 1 -C /cityscapesScripts/ 
RUN cd /cityscapesScripts && python setup.py build_ext install

RUN mkdir /maskrcnn-benchmark
RUN wget -q -O - "https://github.com/facebookresearch/maskrcnn-benchmark/tarball/57eec25b75144d9fb1a6857f32553e1574177daf" | tar xfz - --strip-components 1 -C /maskrcnn-benchmark/


ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility 
ENV NVIDIA_VISIBLE_DEVICES=all

# Run this as a test, because if it fails then maskrcnn-benchmark will fail compiling (and take a long time to fail).
RUN python -c 'import torch; x = torch.Tensor(5, 3); x.cuda()'
RUN cd /maskrcnn-benchmark && CUDA_VISIBLE_DEVICES=0 python setup.py build develop 
RUN apt-get install iputils-ping -y
RUN apt install ffmpeg -y
RUN apt install unzip

# Not sure why but generate_presigned_url doesnt work unless you do this.
WORKDIR /
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install
RUN mkdir ~/.aws/
RUN echo "[default]\nregion = eu-central-1\noutput = json\n" >> ~/.aws/config

RUN pip install opencv-python-headless
RUN pip install redlock-py pycocotools
RUN pip install --upgrade b2
RUN pip install --upgrade boto3
RUN pip install --upgrade selenium unidecode
RUN conda install shapely
