import base64

import urllib3

import os


def lambda_handler(event, context):
    url = f"{os.environ['PROXY_BASE_PATH']}/{event['pathParameters']['proxy']}"

    if event.get('rawQueryString'):
        url = url + "?" + event['rawQueryString']

    print(f"url will be {url}")

    # Two-way to have http method following if lambda proxy is enabled or not
    if event.get('httpMethod'):
        http_method = event['httpMethod']
    else:
        http_method = event['requestContext']['http']['method']

    headers = ''
    if event.get('headers'):
        headers = event['headers']

    # Important to remove the Host header before forwarding the request
    if headers.get('Host'):
        headers.pop('Host')

    if headers.get('host'):
        headers.pop('host')

    body = ''
    if event.get('body'):
        body = event['body']

    try:
        http = urllib3.PoolManager()
        resp = http.request(method=http_method, url=url, headers=headers,
                            body=body)

        print('content-type= ')
        print(resp.headers['content-type'])

        headers_coll = {i: resp.headers[i] for i in resp.headers}
        print('headers_coll = ')
        print(headers_coll)

        if resp.headers['content-type'].find('application/json') > -1 \
                or resp.headers['content-type'].find('text/html') > -1:
            is_binary = False
            body = resp.data.decode('utf-8')
        else:
            is_binary = True
            body = base64.b64encode(resp.data)

        response = {
            "headers": { 
                "Date": resp.headers['Date'],
                "Content-Type": resp.headers['Content-Type'],
                # "Content-Length": resp.headers['content-length'],
                "Connection": resp.headers['Connection']
            },
            # "headers": {i: resp.headers[i] for i in resp.headers},
            "statusCode": resp.status,
            # "body": resp.data.decode('utf-8')
            "isBase64Encoded": is_binary,
            "body": body,
        }

    except Exception as inst:
        print('Connection failed.')
        print(inst)
        response = {
            "statusCode": 500,
            "body": "Connection error"
        }

    return response
