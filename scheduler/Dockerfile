FROM continuumio/miniconda
RUN apt-get update -y
RUN apt-get upgrade -y

RUN conda update --yes conda
RUN conda install dask distributed -c conda-forge --yes

CMD /root/miniconda/bin/dask-scheduler --port 8786 --bokeh-port 8787
EXPOSE 8787 8786