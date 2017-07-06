import api
import json


cov = {
  "type" : "Coverage",
  "domain" : {
    "type" : "Domain",
    "domainType" : "Grid",
    "axes": {
      "lat" : { "values": [x / 100.0 for x in range(3000, 4000)] },
      "lon" : { "values": [x / 100.0 for x in range(3000, 4000)]},
      "t" : { "values": ["2016-03-03T00:00:00UTC", "2016-03-03T00:10:00UTC", "2016-03-03T00:20:00UTC"] }
    },
    "referencing": [{
      "system": {
        "type": "GeographicCRS",
        "id": "http://www.opengis.net/def/crs/EPSG/0/4979"
      }
    }]
  },
  "parameters" : {
    "high_type_cloud_area_fraction": {
      "type" : "Parameter"
    },
    "air_pressure_at_sea_level": {
      "type" : "Parameter"
    }
  }
}

print(
    api.aws_lambda_handeler(cov, None)
)