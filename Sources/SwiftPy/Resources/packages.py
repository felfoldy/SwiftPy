from asyncio import coroutine as _coroutine

__all__ = ['install', 'require']

def _module_path(url: str) -> str:
    parts = url.split('/')
    return Path.site_packages() + "/" + parts[-1]

@_coroutine
def install(url: str) -> None:
    import requests

    response = yield from requests.get(url)
    
    with open(_module_path(url), 'w') as file:
        file.write(response.text)


@_coroutine
def require(url: str) -> None:
    if Path.exists(_module_path(url)):
        return
    
    yield from install(url)
