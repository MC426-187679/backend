"""
Get information for Unicamp disciplines from the 2021 catalog.
"""

from __future__ import annotations
from typing import Any, TypedDict, Optional
import argparse
import bs4
from multiprocessing import Pool
from util import *


DISCIPLINES_URL = 'https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/disciplinas/'
PROCESSES = 12


class Discipline(TypedDict):
    code: str
    name: str
    credits: int
    reqs: Optional[list[list[Requirement]]]
    reqBy: Optional[list[str]]
    syllabus: str


class Requirement(TypedDict):
    code: str
    partial: Optional[bool]
    special: Optional[bool]


def is_discipline_code(code: str) -> bool:
    """
    Checks if code has format of discipline code.
    """
    return len(code) == 5


def get_disciplines_url(initials: str) -> str:
    """
    Return the url for the desired initials.
    """
    return DISCIPLINES_URL + initials.lower().replace(' ', '_') + '.html'


def get_all_initials() -> list[str]:
    """
    Return a list of initials from the catalog.
    """
    soup = load_soup(DISCIPLINES_URL + 'index.html')
    disciplines_class = 'disc' # Part of the tag class.
    initials_tags = soup.find(class_=compile_regex(disciplines_class))
    return [initials.text.upper() for initials in initials_tags.find_all('div')]


def get_disciplines(initials: str) -> bs4.element.ResultSet:
    """
    Get disciplines with desired initials.
    """
    url = get_disciplines_url(initials)
    soup = load_soup(url)
    disciplines_class = 'row' # Tag class that identify a discipline at the page.
    return soup.find_all(class_=disciplines_class)


def create_requirement(raw: str) -> Requirement:
    """
    Create a requirement for the first time, with its code and 'partial' flag.
    """
    # Checks for common discipline code:
    if is_discipline_code(raw):
        code = raw
        return Requirement(code=code)

    # Checks for string of type '*AA000':
    elif is_discipline_code(raw[1:]) and raw[0] == '*':
        code = raw[1:]
        return Requirement(code=code, partial=True)

    else:
        return None


def parse_requirements(raw: str) -> list[list[Requirement]]:
    """
    Parse requirements for a discipline.
    """
    or_string = ' ou '
    and_string = '+'
    groups = raw.split(or_string)

    requirements = list()

    for group in groups:
        group_reqs = [create_requirement(raw) for raw in group.split(and_string)]

        # Checks for non-valid requirements:
        if None in group_reqs:
            return None

        requirements.append(group_reqs)

    return requirements


def parse_disciplines(disciplines: bs4.element.ResultSet) -> dict[str, Discipline]:
    """
    Parse a tag with correct class from disciplines source.
    Builds a map from discipline code to Discipline.
    """
    disciplines_id = 'disc' # Part of the id from the tag with code and name.
    code_name_sep = ' - ' # Discipline code and name separator.
    credits_text = 'créditos' # Part of the text in the credits tag.
    requirements_text = 'requisitos' # Part of the text in the requirements tag.
    syllabus_text = 'ementa' # Part of the text in the syllabus tag.

    disciplines_map = dict()
    for discipline in disciplines:
        try:
            # Discipline code and name:
            code_name_tag = discipline.find(id=compile_regex(disciplines_id))
            code, name = code_name_tag.text.split(code_name_sep, 1)

            # Discipline credits:
            credits_tag = discipline.find(True, string=compile_regex(credits_text))
            credits = int(credits_tag.next_sibling)

            # Discipine requirements:
            requirements_tag = discipline.find(True, string=compile_regex(requirements_text))
            requirements_string = requirements_tag.next_sibling.next_sibling.text # First sibling is just a line break.
            reqs = parse_requirements(requirements_string)

            # Discipline syllabus:
            syllabus_tag = discipline.find(True, string=compile_regex(syllabus_text))
            syllabus = syllabus_tag.next_sibling.next_sibling.text # First sibling is just a line break.

            # Save info:
            new_discipline = Discipline(code=code, name=name, credits=credits, syllabus=syllabus)

            if reqs:
                new_discipline['reqs'] = reqs

            disciplines_map[code] = new_discipline

        except AttributeError:
            continue

    return disciplines_map


def get_discipline(code: str, data: dict[str, dict[str, Discipline]]) -> Discipline:
    """
    Get discipline from all data.
    If there is no such code, None is returned.
    """
    initials_data = data.get(code[0:2])

    if initials_data is None:
        return None
    else:
        return initials_data.get(code)


def add_required_by(requirement: Discipline, discipline_code: str):
    """
    Add the discipline to the 'reqBy' field of requirement.
    """
    if requirement.get('reqBy'):
        requirement['reqBy'].append(discipline_code)
    else:
        requirement['reqBy'] = [discipline_code]


def update_initials_requirements(data: dict[str, Discipline], all_data: dict[str, dict[str, Discipline]]):
    """
    Use all data to update requirements for given initials.
    """
    for code in data:
        discipline = data[code]
        requirement_blocks = discipline.get('reqs')
        if requirement_blocks is not None:
            for block in requirement_blocks:
                for requirement in block:
                    requirement_discipline = get_discipline(requirement['code'], all_data)
                    if requirement_discipline:
                        add_required_by(requirement_discipline, code)
                    else:
                        requirement['special'] = True


def get_disciplines_data(initials: str) -> dict[str, Discipline]:
    """
    Return discipline data for desired initials.
    """
    disciplines_result_set = get_disciplines(initials)
    return parse_disciplines(disciplines_result_set)


def get_all_disciplines_data() -> dict[str, list[Discipline]]:
    """
    Return all discipline data.
    Builds a map from initials to disciplines.
    """
    initial_list = get_all_initials()

    with Pool(PROCESSES) as pool:
        disciplines_data = pool.map(get_disciplines_data, initial_list)
        data = dict(zip(initial_list, disciplines_data))

    # Update requirements 'special' flag:
    for initials in data:
        update_initials_requirements(data[initials], data)

    return {initial: list(content.values()) for initial, content in data.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('DIRECTORY', action='store', nargs=1, type=str,
        help='directory to save output'
    )

    args = parser.parse_args()

    data = get_all_disciplines_data()
    for initials in data:
        dump_content_as_json(data[initials], f"{args.DIRECTORY[0]}/{initials.replace(' ', '_')}.json")


if __name__ == '__main__':
    main()
