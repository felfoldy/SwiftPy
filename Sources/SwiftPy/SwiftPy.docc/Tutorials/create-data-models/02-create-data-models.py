from storages import model, ModelContainer

@model
class Item:
    name: str = ''
    type: str = 'tool'
    quantity: int = 0
    description: str | None

container = ModelContainer('com.company.items-store')
