import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from hello import greet


def test_greet_normal():
    assert greet("world") == "Hello, world!"


def test_greet_empty_string():
    assert greet("") == "Hello, !"


def test_greet_whitespace():
    assert greet("  ") == "Hello,   !"
