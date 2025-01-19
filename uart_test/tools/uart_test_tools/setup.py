#!/usr/bin/env python

from setuptools import setup


def read_requirements():
    with open('requirements.txt', 'rt') as file:
        return file.readlines()


setup(
    name='uart_test_tools',
    packages=['uart_test_tools'],
    version='1.0.0',
    install_requires=[read_requirements()],
    description='UART test tools suite',
    author='Pedro Boechat',
    author_email='pboechat@gmail.com',
    url='https://github.com/pboechat/ice50up5k_tests/uart_test/tools/uart_test_tools',
    entry_points = {
        'console_scripts': [
            'send_command=uart_test_tools.send_command:main'
        ],
    }
)