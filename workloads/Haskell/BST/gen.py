import itertools
import logging
import os
import random
import sys

def _redirect_stdout() -> None:
    log_file = open("/tmp/etna-py.log", "a", buffering=1)
    os.dup2(log_file.fileno(), sys.stdout.fileno())
    sys.stdout = log_file


_redirect_stdout()

from fandango import DerivationTree, Fandango
from fandango.language.grammar import FuzzingMode

class FandangoIterative(Fandango):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._solution_iter = None
        self._cache: list[DerivationTree] = []

    def _ensure_iter(self) -> None:
        if self.fandango is None:
            self.init_population()
        if self._solution_iter is None:
            self._solution_iter = self.generate_solutions(
                max_generations=2,
                mode=FuzzingMode.COMPLETE,
            )

    def fuzz_next(self: 'FandangoIterative', count: int = 1) -> list[DerivationTree]:
        if count <= 0:
            return []

        self._ensure_iter()
        results = list(itertools.islice(self._solution_iter, count))
        
        # Add new results to cache
        self._cache.extend(results)

        if len(results) < count:
            # Generator exhausted, randomly choose from cache to fill remaining
            if self._cache:
                remaining = count - len(results)
                results.extend(random.choices(self._cache, k=remaining))
            else:
                # No cache available, restart the iterator
                self._solution_iter = None
                self._ensure_iter()
                new_results = list(itertools.islice(self._solution_iter, count - len(results)))
                self._cache.extend(new_results)
                results.extend(new_results)

        return results

fandango_file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "grammar.fan")
guided_fandango_file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "grammar_guided.fan")

_fan_by_start: dict[tuple[str, bool], FandangoIterative] = {}

def _get_fan(start_symbol: str, maximizing: bool) -> FandangoIterative:
    key = (start_symbol, maximizing)
    fan = _fan_by_start.get(key)
    if fan is None:
        grammar_path = guided_fandango_file_path if maximizing else fandango_file_path
        with open(grammar_path, "r") as grammar_file:
            # Use a smaller population size to avoid warnings with constrained grammars
            fan = FandangoIterative(grammar_file, start_symbol=start_symbol, logging_level=logging.ERROR)
        _fan_by_start[key] = fan
    return fan

def fuzz_next(start_symbol: str, count: int = 1, maximizing: bool = False) -> list[DerivationTree]:
    fan = _get_fan(start_symbol, maximizing)
    return fan.fuzz_next(count)
