FROM continuumio/miniconda
RUN apt-get update -y
RUN apt-get upgrade -y

RUN conda update --yes conda
RUN conda install dask distributed -c conda-forge --yes
RUN conda install -c conda-forge iris --yes
RUN conda install -c anaconda boto3 --yes

RUN mkdir /app
COPY . /app 
WORKDIR /app

CMD /bin/bash -c "source activate; python processor/__init__.py"