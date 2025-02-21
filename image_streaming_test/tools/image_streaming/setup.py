#!/usr/bin/env python

from setuptools import setup


def read_requirements():
    with open('requirements.txt', 'rt') as file:
        return file.readlines()


setup(
    name='image_streaming',
    packages=['image_streaming'],
    version='1.0.0',
    install_requires=[read_requirements()],
    description='image streaming tools suite',
    author='Pedro Boechat',
    author_email='pboechat@gmail.com',
    url='https://github.com/pboechat/ice50up5k_tests/image_streaming_test/tools/image_streaming',
    entry_points = {
        'console_scripts': [
            'send_image=image_streaming.send_image:main'
        ],
    }
)