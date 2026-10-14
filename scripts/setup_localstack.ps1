$ErrorActionPreference = "Stop"
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"

function awslocal { python -m awscli --endpoint-url=http://localhost:4566 @args }

function Try-Run([scriptblock]$cmd) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & $cmd 2>&1 | Out-Null } catch {}
    $ErrorActionPreference = $old
    $global:LASTEXITCODE = 0
}

# 1. Jalankan LocalStack dan tunggu sehat
docker compose up -d localstack
for ($i = 0; $i -lt 30; $i++) {
    try {
        $h = Invoke-RestMethod http://localhost:4566/_localstack/health -TimeoutSec 3
        if ($h.services.s3 -eq "available" -and $h.services.lambda -eq "available") { break }
    } catch {}
    Start-Sleep -Seconds 5
}

# 2. S3: bucket dan CSV
Try-Run { awslocal s3 mb s3://ptxyz-raw }
foreach ($f in "dataset_alat_berat_dw.csv","dataset_production.csv","dataset_transaksi.csv") {
    awslocal s3 cp "data\$f" "s3://ptxyz-raw/$f"
    if ($LASTEXITCODE -ne 0) { throw "Upload $f gagal" }
}

# 3. Lambda
Compress-Archive -Path lambda_function.py -DestinationPath fn.zip -Force
Try-Run { awslocal lambda delete-function --function-name ptxyz-validate }
awslocal lambda create-function --function-name ptxyz-validate --runtime python3.12 `
  --handler lambda_function.handler --zip-file fileb://fn.zip `
  --role arn:aws:iam::000000000000:role/lambda-role `
  --environment "Variables={LOCALSTACK_ENDPOINT=http://localstack:4566}" | Out-Null

for ($i = 0; $i -lt 60; $i++) {
    $s = awslocal lambda get-function --function-name ptxyz-validate --query Configuration.State --output text
    if ($s -eq "Active") { break }
    Start-Sleep -Seconds 10
}
if ($s -ne "Active") { throw "Lambda tidak Active (state: $s)" }

# 4. EventBridge
awslocal events put-rule --name ptxyz-daily-validate --schedule-expression "rate(1 day)" --state ENABLED | Out-Null
Try-Run { awslocal lambda add-permission --function-name ptxyz-validate --statement-id eb-invoke --action lambda:InvokeFunction --principal events.amazonaws.com --source-arn arn:aws:events:us-east-1:000000000000:rule/ptxyz-daily-validate }
awslocal events put-targets --rule ptxyz-daily-validate --targets "Id=1,Arn=arn:aws:lambda:us-east-1:000000000000:function:ptxyz-validate" | Out-Null

# 5. Bukti: invoke Lambda
awslocal lambda invoke --function-name ptxyz-validate out.json | Out-Null
Get-Content out.json