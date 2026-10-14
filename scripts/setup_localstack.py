import io, json, time, zipfile, os
import boto3
from botocore.exceptions import ClientError

EP = "http://localhost:4566"
kw = dict(endpoint_url=EP, aws_access_key_id="test",
          aws_secret_access_key="test", region_name="us-east-1")
s3 = boto3.client("s3", **kw)
lam = boto3.client("lambda", **kw)
ev = boto3.client("events", **kw)

# 1. Tunggu LocalStack siap
for _ in range(30):
    try:
        import urllib.request
        h = json.load(urllib.request.urlopen(EP + "/_localstack/health", timeout=3))
        if h["services"].get("s3") == "available" and h["services"].get("lambda") == "available":
            break
    except Exception:
        pass
    time.sleep(5)

# 2. S3
try:
    s3.create_bucket(Bucket="ptxyz-raw")
except ClientError as e:
    if e.response["Error"]["Code"] not in ("BucketAlreadyOwnedByYou", "BucketAlreadyExists"):
        raise
for f in ("dataset_alat_berat_dw.csv", "dataset_production.csv", "dataset_transaksi.csv"):
    s3.upload_file(os.path.join("data", f), "ptxyz-raw", f)
print("S3:", [o["Key"] for o in s3.list_objects_v2(Bucket="ptxyz-raw")["Contents"]])

# 3. Lambda
buf = io.BytesIO()
with zipfile.ZipFile(buf, "w") as z:
    z.write("lambda_function.py")
try:
    lam.delete_function(FunctionName="ptxyz-validate")
except ClientError:
    pass
lam.create_function(
    FunctionName="ptxyz-validate", Runtime="python3.12",
    Role="arn:aws:iam::000000000000:role/lambda-role",
    Handler="lambda_function.handler", Code={"ZipFile": buf.getvalue()},
    Environment={"Variables": {"LOCALSTACK_ENDPOINT": "http://localstack:4566"}})
for _ in range(60):
    state = lam.get_function(FunctionName="ptxyz-validate")["Configuration"]["State"]
    if state == "Active":
        break
    time.sleep(10)
if state != "Active":
    raise SystemExit(f"Lambda tidak Active: {state}")

# 4. EventBridge
rule_arn = ev.put_rule(Name="ptxyz-daily-validate",
                       ScheduleExpression="rate(1 day)", State="ENABLED")["RuleArn"]
fn_arn = lam.get_function(FunctionName="ptxyz-validate")["Configuration"]["FunctionArn"]
try:
    lam.add_permission(FunctionName="ptxyz-validate", StatementId="eb-invoke",
                       Action="lambda:InvokeFunction",
                       Principal="events.amazonaws.com", SourceArn=rule_arn)
except ClientError:
    pass
ev.put_targets(Rule="ptxyz-daily-validate", Targets=[{"Id": "1", "Arn": fn_arn}])
print("EventBridge rules:", [r["Name"] for r in ev.list_rules()["Rules"]])
print("Targets:", [t["Arn"] for t in ev.list_targets_by_rule(Rule="ptxyz-daily-validate")["Targets"]])

# 5. Bukti: invoke Lambda
r = lam.invoke(FunctionName="ptxyz-validate")
print("Lambda:", r["Payload"].read().decode())