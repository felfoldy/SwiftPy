from asyncio import coroutine as _coroutine

__all__ = ['install', 'require']


@_coroutine
def install(url: str) -> None:
    import requests

    response = yield from requests.get(url)
    
    with open(_module_path(url), 'w') as file:
        file.write(response.text)


def uninstall(module_name: str) -> None:
    import os
    from pathlib import Path
    
    path = Path.site_packages() + "/" + module_name
    if Path.exists(path):
        os.remove(path)

    os.remove(path + ".py")


@_coroutine
def require(url: str) -> None:
    from pathlib import Path

    if Path.exists(_module_path(url)):
        return

    yield from install(url)

  
def _module_path(url: str) -> str:
    from pathlib import Path

    parts = url.split('/')
    return Path.site_packages() + "/" + parts[-1]
