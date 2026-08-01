from modeling import model
from storage import Store

@model
class Item:
    name: str = ''
    type: str = 'tool'
    quantity: int = 0
    description: str | None

container = Store('com.company.items-store')
