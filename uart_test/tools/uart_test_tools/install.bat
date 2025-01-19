@echo off

if not exist .venv (
	python -m venv .venv
)

.venv\Scripts\activate.bat

pip install -e .
