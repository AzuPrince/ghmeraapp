"""End-to-end checks for workflow_api against the Firebase Local Emulator Suite.

Run from the repo root (needs Java for the Firestore emulator):

    firebase emulators:exec --config firebase.emulator-e2e.json \
        --project demo-ghmera --only auth,firestore,functions \
        "functions/venv/bin/python scripts/workflow_emulator_e2e.py"

Add --in-process to call the handler directly (against the same Auth and
Firestore emulators) where the Functions emulator's Python worker can't run.
Uses a demo- project, so nothing reaches the live Firebase project.
"""

from __future__ import annotations

import concurrent.futures
import copy
import json
import os
import sys
import urllib.error
import urllib.request

from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore

PROJECT_ID = os.environ.get('GCLOUD_PROJECT', 'demo-ghmera')
AUTH_HOST = os.environ['FIREBASE_AUTH_EMULATOR_HOST']
FUNCTIONS_URL = (
    f'http://127.0.0.1:5001/{PROJECT_ID}/us-central1/workflow_api'
)
PASSWORD = 'emulator-only-password'

failures: list[str] = []


def check(condition: bool, label: str) -> None:
    print(('PASS ' if condition else 'FAIL ') + label)
    if not condition:
        failures.append(label)


def _post(url: str, body: dict, headers: dict | None = None) -> tuple[int, dict]:
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={'Content-Type': 'application/json', **(headers or {})},
        method='POST',
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status, json.loads(response.read() or b'{}')
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b'{}')


def create_member(email: str) -> tuple[str, str]:
    """Create a verified emulator account and return (uid, id token)."""
    base = f'http://{AUTH_HOST}/identitytoolkit.googleapis.com/v1'
    _, created = _post(
        f'{base}/accounts:signUp?key=emulator',
        {'email': email, 'password': PASSWORD, 'returnSecureToken': True},
    )
    uid = created['localId']
    _post(
        f'{base}/projects/{PROJECT_ID}/accounts:update',
        {'localId': uid, 'emailVerified': True},
        {'Authorization': 'Bearer owner'},
    )
    _, signed_in = _post(
        f'{base}/accounts:signInWithPassword?key=emulator',
        {'email': email, 'password': PASSWORD, 'returnSecureToken': True},
    )
    return uid, signed_in['idToken']


def user_record(uid: str, email: str, name: str) -> dict:
    return {
        'id': f'user_{uid}',
        'fullName': name,
        'email': email,
        'city': 'Accra',
        'area': 'East Legon',
        'verificationBadges': ['emailVerified'],
        'availability': True,
        'helpCategoriesProvided': ['technicalSupport'],
        'blockedUserIds': [],
        'hiddenRequestIds': [],
        'restrictionStatus': 'clear',
        'isAdmin': False,
    }


def help_request(request_id: str, requester_id: str, **overrides) -> dict:
    request = {
        'id': request_id,
        'requesterId': requester_id,
        'title': 'Router setup',
        'description': 'Please help me set up my router today.',
        'category': 'technicalSupport',
        'urgency': 'medium',
        'location': 'East Legon',
        'preferredTime': 'Today',
        'visibility': 'public',
        'status': 'open',
        'createdAt': '2026-10-12T10:00:00+00:00',
        'acceptedHelperId': None,
        'actionLog': [],
    }
    request.update(overrides)
    return request


IN_PROCESS = '--in-process' in sys.argv


def call(token: str | None, body: dict) -> tuple[int, dict]:
    headers = {'Authorization': f'Bearer {token}'} if token else {}
    if not IN_PROCESS:
        return _post(FUNCTIONS_URL, body, headers)

    # Calls the deployed handler directly, still against the Auth and
    # Firestore emulators, for machines where the Functions emulator's
    # Python worker can't run.
    import flask

    app = flask.Flask('workflow-e2e')
    with app.test_request_context('/', method='POST', json=body, headers=headers):
        response = _workflow_api()(flask.request)
    return response.status_code, json.loads(response.get_data(as_text=True))


def _workflow_api():
    functions_dir = os.path.join(os.path.dirname(__file__), '..', 'functions')
    if functions_dir not in sys.path:
        sys.path.insert(0, functions_dir)
    import firebase_admin
    from firebase_admin import credentials

    class _EmulatorCredential(credentials.Base):
        def get_credential(self):
            return AnonymousCredentials()

    # Production gets credentials from Cloud Functions; the emulators accept
    # anonymous ones.
    real_initialize_app = firebase_admin.initialize_app
    firebase_admin.initialize_app = lambda *args, **kwargs: real_initialize_app(
        _EmulatorCredential(), {'projectId': PROJECT_ID})
    try:
        import main as functions_main
    finally:
        firebase_admin.initialize_app = real_initialize_app

    return functions_main.workflow_api


def own_profile_body(operation: str, user: dict, payload: dict) -> dict:
    return {
        'operation': operation,
        'clientSchema': 2,
        'database': {'_meta': {}, user['email']: {'user': user}},
        'payload': payload,
    }


def saved_database(db) -> dict:
    return db.collection('global_app_state').document('live').get().to_dict()['database']


def saved_request(db, requester_email: str, request_id: str) -> dict:
    for request in saved_database(db)[requester_email]['requests']:
        if request['id'] == request_id:
            return request
    raise KeyError(request_id)


def main() -> int:
    db = firestore.Client(project=PROJECT_ID, credentials=AnonymousCredentials())

    members = {}
    for key, name in (('a', 'Ama Requester'), ('b', 'Ben Helper'), ('c', 'Cee Helper'), ('d', 'Dee Newcomer')):
        email = f'{key}@example.com'
        uid, token = create_member(email)
        members[key] = {'uid': uid, 'token': token, 'email': email,
                        'user': user_record(uid, email, name)}

    a, b, c, d = (members[key] for key in 'abcd')
    database = {
        '_meta': {},
        '_shared': {key: [] for key in ('matches', 'threads', 'messages', 'reviews', 'reports', 'supportCircles')},
    }
    for member in (a, b, c):
        database[member['email']] = {
            'user': member['user'], 'requests': [], 'notifications': [], 'moodCheckIns': [],
        }
    database[a['email']]['requests'] = [
        help_request('request_1', a['user']['id']),
        help_request('request_2', a['user']['id'], title='Printer help'),
    ]
    db.collection('global_app_state').document('live').set({'database': database})
    stale_full_database = copy.deepcopy(database)

    status, body = call(None, {})
    check(status == 401 and body.get('error') == 'Sign in is required.', 'unsigned POST is rejected with 401')

    status, body = call(b['token'], own_profile_body('volunteer_for_help_request', b['user'], {'requestId': 'request_1'}))
    check(status == 200 and body['result'].get('matched') is True, 'new build: B volunteers and the server saves it')
    check(saved_request(db, a['email'], 'request_1')['acceptedHelperId'] == b['user']['id'], 'Firestore shows B as the helper')
    mirror = db.collection('Users_requests').document('sent request').get().to_dict()
    check(mirror[a['email']]['requests'][0]['acceptedHelperId'] == b['user']['id'], 'request mirror was written in the same transaction')

    status, body = call(c['token'], {
        'operation': 'volunteer_for_help_request',
        'database': stale_full_database,
        'payload': {'requestId': 'request_1'},
    })
    check(status == 409 and body.get('error') == 'Someone is already helping with this request.', 'old build with stale copy gets 409 already helping')
    returned = next(r for r in body['database'][a['email']]['requests'] if r['id'] == 'request_1')
    check(returned['acceptedHelperId'] == b['user']['id'], '409 response carries the saved request')

    tampered = copy.deepcopy(stale_full_database)
    tampered[b['email']]['user']['fullName'] = 'Hacked Name'
    tampered[b['email']]['user']['isAdmin'] = True
    tampered[c['email']]['user']['city'] = 'Tema'
    status, _ = call(c['token'], {'operation': 'update_my_notifications', 'database': tampered, 'payload': {'markAllRead': True}})
    saved = saved_database(db)
    check(status == 200, 'old build full-database request still works')
    check(saved_request(db, a['email'], 'request_1')['acceptedHelperId'] == b['user']['id'], 'stale phone did not revert the acceptance')
    check(saved[b['email']]['user']['fullName'] == 'Ben Helper' and not saved[b['email']]['user']['isAdmin'], "stale phone did not overwrite B's profile")
    check(saved[c['email']]['user']['city'] == 'Tema', "old build's own unsaved profile edit was kept")

    edited = dict(c['user'], fullName='Cee Updated', isAdmin=True, verificationBadges=['emailVerified', 'idVerified'])
    status, _ = call(c['token'], own_profile_body('sync_my_profile', edited, {'user': edited}))
    saved_c = saved_database(db)[c['email']]['user']
    check(status == 200 and saved_c['fullName'] == 'Cee Updated', 'sync_my_profile saves own name')
    check(not saved_c['isAdmin'] and 'idVerified' not in saved_c['verificationBadges'], 'sync_my_profile cannot grant admin or ID badges')

    status, body = call(c['token'], own_profile_body('sync_my_profile', a['user'], {'user': a['user']}))
    check(status == 403, "sync_my_profile rejects someone else's profile")

    status, _ = call(d['token'], own_profile_body('sync_my_profile', d['user'], {'user': d['user']}))
    check(status == 200 and d['email'] in saved_database(db), 'brand-new member is created by the server')

    def volunteer(member):
        return call(member['token'], own_profile_body('volunteer_for_help_request', member['user'], {'requestId': 'request_2'}))

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(volunteer, (c, d)))
    statuses = sorted(status for status, _ in results)
    winner = saved_request(db, a['email'], 'request_2')['acceptedHelperId']
    check(statuses == [200, 409], f'two simultaneous volunteers: exactly one wins (statuses {statuses})')
    check(winner in {c['user']['id'], d['user']['id']}, 'saved request names the single winner')

    print(f"\n{len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
