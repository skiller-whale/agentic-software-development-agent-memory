from notes import NotesStore


def test_add_and_list():
    store = NotesStore()
    store.add("Shopping", "Milk, eggs")
    notes = store.list()
    assert len(notes) == 1
    assert notes[0]["title"] == "Shopping"


def test_delete():
    store = NotesStore()
    note = store.add("Temp", "delete me")
    assert store.delete(note["id"]) is True
    assert store.list() == []


def test_get_missing_returns_none():
    store = NotesStore()
    assert store.get(999) is None
