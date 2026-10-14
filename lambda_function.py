import os
import boto3

ENDPOINT = os.environ.get("AWS_ENDPOINT_URL") or "http://host.docker.internal:4566"
BUCKET = "ptxyz-raw"
# Jumlah baris data (tanpa header) yang diharapkan di CSV staging
EXPECTED = {
    "dataset_alat_berat_dw.csv": 1150,
    "dataset_production.csv": 1150,
    "dataset_transaksi.csv": 1150,
}

def handler(event, context):
    s3 = boto3.client(
        "s3",
        endpoint_url=os.environ.get("LOCALSTACK_ENDPOINT", "http://localstack:4566"),
        aws_access_key_id="test",
        aws_secret_access_key="test",
        region_name="us-east-1",
    )
    result = {}
    for key, expected in EXPECTED.items():
        body = s3.get_object(Bucket=BUCKET, Key=key)["Body"].read().decode("utf-8")
        rows = len([l for l in body.splitlines() if l.strip()]) - 1
        result[key] = {"rows": rows, "expected": expected,
                       "status": "PASS" if rows == expected else "FAIL"}
    return result