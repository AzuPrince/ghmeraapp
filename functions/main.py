from firebase_functions import https_fn, firestore_fn
from firebase_admin import initialize_app, firestore

initialize_app()

@https_fn.on_request()
def hello_world(req: https_fn.Request) -> https_fn.Response:
    return https_fn.Response("Hello from Ghmera Cloud Functions!")

@firestore_fn.on_document_created(document="HelpRequests/{requestId}")
def match_request(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]) -> None:
    """
    Triggered when a new HelpRequest is created.
    Finds available helpers in the same category and pushes to HelpMatches collection.
    """
    if event.data is None:
        return
    
    request_data = event.data.to_dict()
    category = request_data.get("category")
    
    db = firestore.client()
    # Simple matching algorithm constraint: Helpers available and matching category
    helpers_query = db.collection("Users").where("availability", "==", True).where("helpCategories", "array_contains", category).limit(5).get()
    
    for helper in helpers_query:
        # Create a HelpMatch
        match_ref = db.collection("HelpMatches").document()
        match_ref.set({
            "requester_id": request_data.get("requesterId"),
            "helper_id": helper.id,
            "request_id": event.data.id,
            "status": "matching",
            "created_at": firestore.SERVER_TIMESTAMP
        })
        print(f"Match created for helper {helper.id} on request {event.data.id}")
