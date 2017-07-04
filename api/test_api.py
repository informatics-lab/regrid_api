import api
import json


covjson = """{
  "type" : "Coverage",
  "domain" : {
    "type" : "Domain",
    "domainType" : "Grid",
    "axes": {
      "x" : { "values": [-10,-5,0] },
      "y" : { "values": [40,50] },
      "t" : { "values": ["2010-01-01T00:12:20Z"] }
    },
    "referencing": [{
      "system": {
        "type": "GeographicCRS",
        "id": "http://www.opengis.net/def/crs/EPSG/0/4979"
      }
    }]
  }
}"""

print(
    api.aws_lambda_handeler(json.loads(covjson), None)
)