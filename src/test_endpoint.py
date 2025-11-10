#!/usr/bin/env python3
import argparse
import json
import requests

parser = argparse.ArgumentParser()
parser.add_argument('--url', required=True)
parser.add_argument('--key', required=False)
args = parser.parse_args()

headers = {'Content-Type': 'application/json'}
if args.key:
    headers['Authorization'] = f'Bearer {args.key}'

payload = {"input_data": [[0]]}  # replace with a valid payload for your model

resp = requests.post(args.url, headers=headers, json=payload, timeout=30)
print('Status:', resp.status_code)
try:
    print(resp.json())
except Exception:
    print(resp.text)

if resp.status_code >= 400:
    raise SystemExit(1)
