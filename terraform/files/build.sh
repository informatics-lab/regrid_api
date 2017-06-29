#! /bin/bash
pushd ../api/ 2>&1 >/dev/null
rm ../terraform/files/lambda.zip  2>&1 >/dev/null
zip -r ../terraform/files/lambda.zip * 2>&1 >/dev/null
popd 2>&1 >/dev/null
echo '{"path" : "files/lambda.zip"}'