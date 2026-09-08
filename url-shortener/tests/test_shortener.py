from shortener import code_for, expand, shorten


def test_code_is_six_chars():
    assert len(code_for("https://example.com")) == 6


def test_same_url_same_code():
    assert code_for("https://example.com") == code_for("https://example.com")


def test_round_trip():
    code = shorten("https://example.com/page")
    assert expand(code) == "https://example.com/page"


def test_unknown_code_is_none():
    assert expand("nope00") is None
