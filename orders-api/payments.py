# Simulates a flaky payment provider: every third call fails, the rest
# succeed with a fake charge id.

_calls = 0


class PaymentUnavailable(Exception):
    pass


def charge(amount):
    global _calls
    _calls += 1
    if _calls % 3 == 0:
        raise PaymentUnavailable("provider unavailable")
    return f"ch_{_calls:04d}"
