orders-api. A tiny stdlib-only Python service that accepts orders and
charges a payment provider for them.

Run it with `python app.py`.

## Setup

1. Install dependencies: `pip3 install --user -r requirements.txt`
2. Copy `.env.example` to `.env`
3. Run the tests: `python3 -m pytest -q`

## Testing

Unit tests are in `tests/`, run with `pytest -q`. Integration tests
are in `tests/integration/`.
