import json

from firebase_admin import initialize_app
from firebase_functions import https_fn

from workflow_api import WorkflowError, apply_workflow_operation

initialize_app()

@https_fn.on_request()
def hello_world(req: https_fn.Request) -> https_fn.Response:
    return https_fn.Response("Hello from Ghmera Cloud Functions!")

def _cors_headers(origin: str | None) -> dict[str, str]:
    return {
        'Access-Control-Allow-Origin': origin or '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }


@https_fn.on_request()
def workflow_api(req: https_fn.Request) -> https_fn.Response:
    headers = _cors_headers(req.headers.get('Origin'))

    if req.method == 'OPTIONS':
        return https_fn.Response('', status=204, headers=headers)

    if req.method != 'POST':
        return https_fn.Response(
            json.dumps({'ok': False, 'error': 'Method not allowed.'}),
            status=405,
            headers=headers,
            content_type='application/json',
        )

    try:
        body = req.get_json(silent=True)
        if not isinstance(body, dict):
            raise WorkflowError('Invalid JSON body.')

        updated_database, result = apply_workflow_operation(body)
        return https_fn.Response(
            json.dumps({'ok': True, 'database': updated_database, 'result': result}),
            status=200,
            headers=headers,
            content_type='application/json',
        )
    except WorkflowError as error:
        return https_fn.Response(
            json.dumps({'ok': False, 'error': error.message}),
            status=error.status_code,
            headers=headers,
            content_type='application/json',
        )
    except Exception as error:
        print(f'Workflow API failed: {error}')
        return https_fn.Response(
            json.dumps({'ok': False, 'error': 'Internal server error.'}),
            status=500,
            headers=headers,
            content_type='application/json',
        )
