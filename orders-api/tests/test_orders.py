import payments


def test_charge_returns_id_on_success():
    payments._calls = 0
    assert payments.charge(100).startswith("ch_")


def test_charge_raises_on_third_call():
    payments._calls = 0
    payments.charge(100)
    payments.charge(100)
    try:
        payments.charge(100)
        assert False, "expected PaymentUnavailable"
    except payments.PaymentUnavailable:
        pass
