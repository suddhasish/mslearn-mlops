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

# Sample data: Pregnancies,PlasmaGlucose,DiastolicBloodPressure,TricepsThickness,SerumInsulin,BMI,DiabetesPedigree,Age,Diabetic
payload = {"input_data": [[1, 78, 41, 33, 311, 50.79, 0.42, 24, 0]]}

resp = requests.post(args.url, headers=headers, json=payload, timeout=30)
print('Status:', resp.status_code)
try:
    print(resp.json())
except Exception:
    print(resp.text)

if resp.status_code >= 400:
    raise SystemExit(1)
