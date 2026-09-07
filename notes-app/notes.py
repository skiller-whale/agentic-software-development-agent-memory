"""In-memory note storage used by the notes API."""


class NotesStore:
    def __init__(self):
        self._notes = {}
        self._next_id = 1

    def add(self, title, body):
        note_id = self._next_id
        self._notes[note_id] = {"id": note_id, "title": title, "body": body}
        self._next_id += 1
        return self._notes[note_id]

    def list(self):
        return list(self._notes.values())

    def get(self, note_id):
        return self._notes.get(note_id)

    def delete(self, note_id):
        return self._notes.pop(note_id, None) is not None
