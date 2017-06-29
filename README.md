# ERDC Regridding API
API for regriding MOGREPS data

# Gotchas

Current version of terraform (0.9.8) file provisner fails with symlinks. Make sure there arn't any such as those created by conda in a `bin` folder when doing `source activate <my_env>`.

Current version of terraform (0.9.7) [breaks provisioners using template_file with "Must provide one of 'content' or 'source'"](https://github.com/hashicorp/terraform/issues/15177). Solution use terraform 0.9.6.

Set up account id var
export TF_VAR_aws_account_id=$AWS_ACCOUNT_ID


Always get this error fist apply after destroy. Re-run for success.
```
* module.api.aws_api_gateway_integration_response.integrationResponse: 1 error(s) occurred:

* aws_api_gateway_integration_response.integrationResponse: Error creating API Gateway Integration Response: NotFoundException: No integration defined for method
	status code: 404, request id: 7093b8d5-5c14-11e7-9f8d-4568e6519b4e
```