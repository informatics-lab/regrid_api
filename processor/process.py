import boto3            
import time
import sys
import distributed
import os
import json

import uuid
import traceback

import iris
iris.FUTURE.cell_datetime_objects = True
iris.FUTURE.netcdf_promote = True
iris.FUTURE.netcdf_no_unlimited = True
import cf_units
from itertools import product
from datetime import datetime, timedelta
import urllib
import numpy as np
from dask import delayed
import dask.bag as db
import dask
import urllib.request

print ('Processor starting')

QUEUE_NAME = os.environ['QUEUE_NAME'] 
BUCKET = os.environ['BUCKET_NAME']

print ("Queue = %s" % QUEUE_NAME)

sqs = boto3.resource('sqs', region_name='eu-west-1')
s3 = boto3.resource('s3', region_name='eu-west-1')
queue = sqs.get_queue_by_name(QueueName=QUEUE_NAME)


print('connected to sqs')

client = None;
while not client:
    try:
        client = distributed.Client('localhost:8786') 
    except Exception as e:
        print(e)

print('connected to scheduler.', client)

while len(client.ncores().keys()) < 1:
    print("Client not ready ", client)
    time.sleep(30)


def make_status_file_bytes(result_url):
    return json.dumps({"status":"done", "result":result_url}).encode('utf-8')

def upload_status_file(job_id, result_url):
    s3.Bucket(BUCKET).put_object(
        Key="%s/status" % job_id, 
        Body=make_status_file_bytes(result_url), 
        ContentType='application/json')
    return "https://s3-eu-west-1.amazonaws.com/%s/%s/status" % (BUCKET, job_id)

def upload_result(job_id, file_path):
    with open(file_path, 'rb') as result:
        s3.Bucket(BUCKET).put_object(
            Key="%s/result.nc" % job_id, 
            Body=result.read(), 
            ContentType='application/x-netcdf')
    return "https://s3-eu-west-1.amazonaws.com/%s/%s/result.nc" % (BUCKET, job_id)


def process(msg):
    body = json.loads(msg.body)
    print(body)
    job_id = body['id']
    print("dates:", body['domain']['axes']['t'])
    datetimes = [datetime.strptime(time, "%Y-%m-%dT%H:%M:%S%Z") for time in body['domain']['axes']['t']['values']]
    params = body['parameters'].keys()
    lats = body['domain']['axes']['lat']['values']
    lons = body['domain']['axes']['lon']['values']
        
    results = leeroyjenkins(datetimes, lats=lats, lons=lons, params=params)
    mycubes = results.compute()
    path = "/tmp/%s.nc" % uuid.uuid4().hex
    iris.save(mycubes, path)

    result_url = upload_result(job_id, path)
    upload_status_file(job_id, result_url)
    print("Message processed, will delete. Result at %s" % result_url)
    msg.delete()
    os.remove(path)



def process_all_messages():
    for msg in queue.receive_messages():
        try:
            process(msg)
        except Exception as e:
            traceback.print_exc()

        
## From ERDC Regrid notebook
lats = [x / 100.0 for x in range(3000, 4000)]
lons = [x / 100.0 for x in range(3000, 4000)]



def make_data_object_name(dataset_name, forecast_reference_time, forecast_period, realization=0):
    template_string = "prods_op_{}_{:02d}{:02d}{:02d}_{:02d}_{:02d}_{:03d}.nc"
    return template_string.format(dataset_name,
                                  forecast_reference_time.year,
                                  forecast_reference_time.month,
                                  forecast_reference_time.day,
                                  forecast_reference_time.hour,
                                  realization,
                                  forecast_period)


def download_data_object(dataset_name, data_object_name):
    dest = '/tmp/' + data_object_name
    if not os.path.exists(dest):
        url = "https://s3.eu-west-2.amazonaws.com/" + dataset_name + "/" + data_object_name
        print(url)
        urllib.request.urlretrieve(url, '/tmp/' + data_object_name) # save in this directory with same name

    return dest



MODELS = {
    'mogreps-g': {
        'valid_frt_hours' : list(range(0, 24, 6)), # valid forecast reference time hours of the day
        'valid_forecast_hours': list(range(0, 24, 3))
    }
}


def leeroyjenkins(times, lons, lats, params):
    """
    Args:
        * times (iterable of datetime.datetime), forecast reference time
        * lons (iterable of numerics)
        * lats (iterable of numerics)
        
    """

    remote_data_uris = find_data(lats, lons, times)
    local_data_uris = retrieve_data(remote_data_uris)
    processed_data = process_data(local_data_uris, lats, lons, times, params)
    return processed_data
#     processed_data_uris = export_data(processed_data, endpoint)


def most_recent_forecast(request_time, dataset='mogreps-g'):
    # convert to valid forecast time
    # Find nearest lead time to this in global
    valid_forecast_hours = MODELS[dataset]['valid_frt_hours']
    
    valid_hour = min(valid_forecast_hours, key=lambda x: abs(x - request_time.hour))
    valid_forecast_time = request_time.replace(hour=valid_hour)
    
    return make_data_object_name(dataset, valid_forecast_time, 3)

    
def find_data(lats, lons, times, data_set='mogreps-g'):
    remote_data_uris = []
    for time in times:
        remote_data_uri = most_recent_forecast(time)
        remote_data_uris.append(remote_data_uri)
    return remote_data_uris
    

def retrieve_data(remote_data_uris, data_set='mogreps-g'):
    retrieved_files = []
    for remote_data_uri in remote_data_uris:
        retrieved_file = download_data_object(data_set, remote_data_uri)
        retrieved_files.append(retrieved_file)

    return retrieved_files


def process_data(local_data_uris, lats, lons, times, params,
                 regridding_scheme=iris.analysis.Linear(),
                 chunksize=100):
    processed_cubes = [process_a_param(a_param, local_data_uris, lats, lons, times, regridding_scheme, chunksize)
                                        for a_param in params]
    return dask.delayed(processed_cubes)
    

def process_a_param(a_param, local_data_uris, lats, lons, times, regridding_scheme, chunksize):
    a_cube = iris.load_cube(local_data_uris, a_param)
    tc = a_cube.coord("time").units
    tpts = [cf_units.date2num(t, tc.name, tc.calendar) for t in times]
    template_time_coord = a_cube.coord("time").copy(points=tpts)
    template_lon_coord = a_cube.coord("longitude").copy(points=lons)
    template_lat_coord = a_cube.coord("latitude").copy(points=lats)
    # fix junk bounds issue...
    template_lon_coord.circular = False
    template_lon_coord.guess_bounds()
    template_lat_coord.guess_bounds()

    a_cube.coord('latitude').guess_bounds()
    a_cube.coord('longitude').guess_bounds()
    template_cube = iris.cube.Cube(np.empty((len(times), len(lons), len(lats))),
                                   dim_coords_and_dims=[(template_time_coord, 0),
                                                        (template_lon_coord, 1),
                                                        (template_lat_coord, 2)])
    lat_indexes = range(0, len(lats) + 1, chunksize)
    lon_indexes = range(0, len(lons) + 1, chunksize)
    slice_points = product(lat_indexes, lon_indexes)
    template_chunks = iris.cube.CubeList([template_cube[:, x:x+chunksize, y:y+chunksize]
                                                                for x,y in slice_points
                                                                    if x < len(lons)
                                                                   and y < len(lats)])
    output = [regrid(a_cube, t_chunk, regridding_scheme) for t_chunk in template_chunks]

    cl = dask.delayed(iris.cube.CubeList)(output)
    cube = cl.concatenate_cube()
    return cube


@delayed
def regrid(source_cube, template_cube, scheme):
    return source_cube.regrid(template_cube, scheme)

def export_data(processed_data, endpoint):
    pass

params = ['wet_bulb_freezing_level_altitude', 'air_pressure_at_sea_level', 'dew_point_temperature',
          'fog_area_fraction', 'visibility_in_air', 'high_type_cloud_area_fraction']


# go 
        

if __name__ == '__main__':
    print ('Waiting for messages')
    while True:
        process_all_messages()
        print("sleep for a bit")
        sys.stdout.flush()
        time.sleep(5)