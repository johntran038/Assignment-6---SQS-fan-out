import os
import json
import boto3
from io import BytesIO
from PIL import Image

s3 = boto3.client("s3")

OUTPUT_BUCKET = os.environ.get("OUTPUT_BUCKET")
THUMBNAIL_SIZE = os.environ.get("THUMBNAIL_SIZE", "128x128")

def parse_size(size_str):
    w, h = size_str.lower().split("x")
    return int(w), int(h)

def lambda_handler(event, context):
    for record in event["Records"]:
        body = json.loads(record["body"])
        sns_message = json.loads(body["Message"])

        for s3_record in sns_message["Records"]:
            bucket = s3_record["s3"]["bucket"]["name"]
            key = s3_record["s3"]["object"]["key"]
            process_image(bucket, key)

    return {"status": "done"}

def process_image(bucket, key):
    obj = s3.get_object(Bucket=bucket, Key=key)
    img_data = obj["Body"].read()

    img = Image.open(BytesIO(img_data))
    img = img.convert("RGB")

    size = parse_size(THUMBNAIL_SIZE)
    img.thumbnail(size)

    base = key.split("/")[-1]
    name, ext = os.path.splitext(base)
    thumb_key = f"thumbnails/{name}_thumb.jpg"

    buffer = BytesIO()
    img.save(buffer, format="JPEG")
    buffer.seek(0)

    s3.put_object(
        Bucket=OUTPUT_BUCKET,
        Key=thumb_key,
        Body=buffer,
        ContentType="image/jpeg"
    )
