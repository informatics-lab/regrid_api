# ERDC Regridding API
API for regriding MOGREPS data

# Gotchas

Current version of terraform (0.9.8) file provisner fails with symlinks. Make sure there arn't any such as those created by conda in a `bin` folder when doing `source activate <my_env>`.

Current version of terraform (0.9.7) [breaks provisioners using template_file with "Must provide one of 'content' or 'source'"](https://github.com/hashicorp/terraform/issues/15177). Solution use terraform 0.9.6.