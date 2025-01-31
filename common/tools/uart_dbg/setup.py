#!/usr/bin/env python

from setuptools import setup


def read_requirements():
    with open('requirements.txt', 'rt') as file:
        return file.readlines()


setup(
    name='uart_dbg',
    packages=['uart_dbg'],
    version='1.0.0',
    install_requires=[read_requirements()],
    description='UART dbg',
    author='Pedro Boechat',
    author_email='pboechat@gmail.com',
    url='https://github.com/pboechat/ice50up5k_tests/common/tools/uart_dbg',
    entry_points = {
        'console_scripts': [
            'uart_dbg=uart_dbg:main'
        ],
    }
)