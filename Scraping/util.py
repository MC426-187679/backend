from typing import Pattern
import bs4
import requests
import json
import re

def load_soup(url: str) -> bs4.BeautifulSoup:
    """
    Load BeautifulSoup data from desired url.
    """
    return bs4.BeautifulSoup(requests.get(url).content, 'html.parser')

def dump_content_as_json(content: dict, filename: str):
    """
    Save content in content as a json.
    """
    with open(filename, 'w') as file:
        json.dump(content, file, indent=4, ensure_ascii=False)

def compile_regex(string: str) -> Pattern[str]:
    """
    Compile text as regex and return
    """
    return re.compile(string, flags=re.IGNORECASE)
