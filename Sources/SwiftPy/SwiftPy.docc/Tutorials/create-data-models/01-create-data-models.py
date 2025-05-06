from storages import model

@model
class Item:
    name: str = ''
    type: str = 'tool'
    quantity: int = 0
    description: str | None
