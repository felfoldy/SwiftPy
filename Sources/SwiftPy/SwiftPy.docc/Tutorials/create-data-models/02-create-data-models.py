from modeling import model
from storage import Container

@model
class Item:
    name: str = ''
    type: str = 'tool'
    quantity: int = 0
    description: str | None

container = Container('com.company.items-store')
