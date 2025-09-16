from flask import Flask, request, jsonify
from flask.json.provider import DefaultJSONProvider
from flask_pymongo import PyMongo
from flask_cors import CORS
from bson import ObjectId
from datetime import datetime
import os

# This custom provider will handle `datetime` and `ObjectId` types
class CustomJSONProvider(DefaultJSONProvider):
    def default(self, o):
        if isinstance(o, datetime):
            return o.isoformat()
        if isinstance(o, ObjectId):
            return str(o)
        return super().default(o)

app = Flask(__name__)
# Use our custom provider for all JSON operations
app.json_provider_class = CustomJSONProvider
app.json = app.json_provider_class(app)

app.config["MONGO_URI"] = os.getenv("MONGO_URI", "mongodb://localhost:27017/pocketzone")
mongo = PyMongo(app)
CORS(app)  # povolí volání z Flutteru (localhost, emulátory)

def oid(x): return ObjectId(x) if isinstance(x, str) else x

def ensure_indexes():
    try:
        mongo.db.pitches.create_index([("pitcherId", 1), ("ts", -1)])
        mongo.db.pitches.create_index([("result", 1)])
        mongo.db.pitches.create_index([("type", 1)])
    except Exception as e:
        app.logger.warning(f"Index init warning: {e}")

ensure_indexes()

# ---------------- Pitchers ----------------
@app.post("/pitchers")
def create_pitcher():
    data = request.get_json() or {}
    doc = {
        "name": data.get("name"),
        "team": data.get("team"),
        "hand": data.get("hand"),   # 'R' / 'L'
        "createdAt": datetime.utcnow()
    }
    if not doc["name"]:
        return jsonify({"error": "name is required"}), 400
    res = mongo.db.pitchers.insert_one(doc)
    doc["_id"] = res.inserted_id
    return jsonify(doc), 201

@app.get("/pitchers")
def list_pitchers():
    cur = mongo.db.pitchers.find().sort("createdAt", -1)
    # The custom provider will handle the serialization of each document
    return jsonify(list(cur))

# ---------------- Pitches ----------------
@app.post("/pitches")
def create_pitch():
    d = request.get_json() or {}
    required = ["pitcherId", "x", "y", "inZone", "type", "result"]
    if any(k not in d for k in required):
        return jsonify({"error": f"Missing one of {required}"}), 400
    try:
        x = float(d["x"]); y = float(d["y"])
        inZone = bool(d["inZone"])
    except:
        return jsonify({"error":"x,y must be numbers; inZone bool"}), 400

    pitch = {
        "pitcherId": oid(d["pitcherId"]),
        "x": x, "y": y, "inZone": inZone,
        "type": d["type"],
        "result": d["result"],
        "speedKph": d.get("speedKph"),
        "ts": datetime.utcnow()
    }
    res = mongo.db.pitches.insert_one(pitch)
    pitch["_id"] = res.inserted_id
    return jsonify(pitch), 201

@app.get("/pitches")
def list_pitches():
    q = {}
    if pid := request.args.get("pitcherId"):
        q["pitcherId"] = oid(pid)
    if r := request.args.get("result"):
        q["result"] = r
    if t := request.args.get("type"):
        q["type"] = t
    if iz := request.args.get("inZone"):
        q["inZone"] = (iz.lower() == "true")
    
    dt = {}
    if frm := request.args.get("from"):
        dt["$gte"] = datetime.fromisoformat(frm)
    if to := request.args.get("to"):
        dt["$lte"] = datetime.fromisoformat(to)
    if dt: q["ts"] = dt

    page = int(request.args.get("page", 1))
    limit = min(200, int(request.args.get("limit", 50)))
    skip = (page - 1) * limit

    cur = mongo.db.pitches.find(q).sort("ts", -1).skip(skip).limit(limit)
    items = list(cur)
    return jsonify({"items": items, "page": page, "limit": limit})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5001)))
