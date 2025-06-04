cd "$(dirname "$0")"
python3 -m venv .venv
source .venv/bin/activate
pip install -r ../requirements.txt
uvicorn app:app --host 127.0.0.1 --port 9000
# backend starter, a lot of docs