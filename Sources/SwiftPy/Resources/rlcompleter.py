#
#  rlcompleter.py
#  SwiftPy
#
#  Created by Tibor Felföldy on 2025-01-24.
#

import __main__
import builtins
import inspect

class Completer:
    def __init__(self, namespace = None):
        """Create a new completer for the command line.

        Completer([namespace]) -> completer instance.

        If unspecified, the default namespace where completions are performed
        is __main__ (technically, __main__.__dict__). Namespaces should be
        given as dictionaries.
        """

        if namespace and not isinstance(namespace, dict):
            raise TypeError('namespace must be a dictionary')

        # Don't bind to namespace quite yet, but flag whether the user wants a
        # specific namespace or to use __main__.__dict__. This will allow us
        # to bind to __main__.__dict__ at completion time, not now.
        if namespace is None:
            self.use_main_ns = 1
        else:
            self.use_main_ns = 0
            self.namespace = namespace
            
    def complete(self, text, state):
        """Return the next possible completion for 'text'.

        This is called successively with state == 0, 1, 2, ... until it
        returns None.  The completion should begin with 'text'.

        """
        if self.use_main_ns:
            self.namespace = __main__.__dict__

        if not text.strip():
            if state == 0:
                return '\t'
            else:
                return None
                
        if state == 0:
            if "." in text:
                self.matches = self.attr_matches(text)
            else:
                self.matches = self.global_matches(text)

        try:
            return self.matches[state]
        except IndexError:
            return None


    def _callable_postfix(self, val, word):
        if callable(val):
            word += "("
            # TODO: no signature in inspect
            # try:
            #     if not inspect.signature(val).parameters:
            #         word += ")"
            # except ValueError:
            #     pass

        return word


    def global_matches(self, text):
        """Compute matches when text is a simple name.

        Return a list of all keywords, built-in functions and names currently
        defined in self.namespace that match.
        """
        matches = []
        seen = {"__builtins__"}
        n = len(text)
        
        # TODO: no keyword module
        # for word in keyword.kwlist + keyword.softkwlist:
        #     if word[:n] == text:
        #         seen.add(word)
        #         if word in {'finally', 'try'}:
        #             word = word + ':'
        #         elif word not in {'False', 'None', 'True',
        #                           'break', 'continue', 'pass',
        #                           'else', '_'}:
        #             word = word + ' '
        #         matches.append(word)
        
        for nspace in [self.namespace, builtins.__dict__]:
            for word, val in nspace.items():
                if word[:n] == text and word not in seen:
                    seen.add(word)
                    matches.append(self._callable_postfix(val, word))
        
        return matches


    def attr_matches(self, text):
        """Compute matches when text contains a dot.

        Assuming the text is of the form NAME.NAME....[NAME], and is
        evaluable in self.namespace, it will be evaluated and its attributes
        (as revealed by dir()) are used as possible completions.  (For class
        instances, class members are also considered.)

        WARNING: this can still invoke arbitrary C code, if an object
        with a __getattr__ hook is evaluated.
        """
        
        # TODO: no re lib
        # m = re.match(r"(\w+(\.\w+)*)\.(\w*)", text)
        # if not m:
        #     return []
        # expr, attr = m.group(1, 3)
        
        # Workaround:
        parts = text.split('.')

        if len(parts) < 2:
            return []
        
        expr = '.'.join(parts[:-1])
        attr = parts[-1]
        
        try:
            thisobject = eval(expr, self.namespace)
        except Exception:
            return []
        
        words = set(dir(thisobject))
        words.discard("__builtins__")
        
        if hasattr(thisobject, '__class__'):
            words.add('__class__')
            words.update(get_class_members(thisobject.__class__))
        
        matches = []
        n = len(attr)
        if attr == '':
            noprefix = '_'
        elif attr == '_':
            noprefix = '__'
        else:
            noprefix = None
        
        while True:
            for word in words:
                if (word[:n] == attr and not (noprefix and word[:n+1] == noprefix)):
                    
                    match = f"{expr}.{word}"
                    
                    attribute = getattr(type(thisobject), word, None)
                    if isinstance(attribute, property):
                        # bpo-44752: thisobject.word is a method decorated by
                        # `@property`. What follows applies a postfix if
                        # thisobject.word is callable, but know we know that
                        # this is not callable (because it is a property).
                        # Also, getattr(thisobject, word) will evaluate the
                        # property method, which is not desirable.
                        matches.append(match)
                        continue

                    value = getattr(thisobject, word, None)
                    if value is not None:
                        matches.append(self._callable_postfix(value, match))
                    else:
                        matches.append(match)

            if matches or not noprefix:
                break
            if noprefix == '_':
                noprefix = '__'
            else:
                noprefix = None
        
        matches.sort()
        return matches
        
    def get_class_members(klass):
        ret = dir(klass)
        if hasattr(klass,'__bases__'):
            for base in klass.__bases__:
                ret = ret + get_class_members(base)
        return ret
