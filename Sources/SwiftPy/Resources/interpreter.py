from rlcompleter import Completer

text_to_complete = ''

def completions() -> list[str]:
    completer = Completer()

    completion_list = []
    state = 0
    
    # Get completions until no more are found
    while True:
        completion = completer.complete(text_to_complete, state)
        if completion is None:
            break
        completion_list.append(completion)
        state += 1
    
    return completion_list
