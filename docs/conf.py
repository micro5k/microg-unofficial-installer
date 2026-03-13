#!/usr/bin/env python
# -*- coding: utf-8 -*-
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

# Configuration file for the Sphinx documentation builder
# For the full list of built-in configuration values, see the documentation: https://www.sphinx-doc.org/en/master/usage/configuration.html

import os
import re
import subprocess

# Functions
def get_version():
    props_path = os.path.join(os.path.dirname(__file__), '..', 'zip-content', 'module.prop')

    if os.path.exists(props_path):
        with open(props_path, 'r') as f:
            for line in f:
                if line.startswith('version='):
                    return line.replace('version=', '').lstrip('v').strip()
    return '0.0.0-unknown'

def get_revision():
    # Try Read the Docs env vars first
    git_rev = os.environ.get('READTHEDOCS_GIT_COMMIT_HASH')
    git_id = os.environ.get('READTHEDOCS_GIT_IDENTIFIER')
    if git_rev:
        git_rev = git_rev[:8]
        return f"{git_rev} ({git_id})" if git_id else git_rev

    # Local Git fallback
    try:
        return subprocess.check_output(
            ['git', 'rev-parse', '--short=8', 'HEAD'], stderr=subprocess.DEVNULL
        ).decode('utf-8').strip()
    except Exception:
        return None

def fix_html_links(app, pagename, templatename, context, doctree):
    """Fixes links in HTML output."""
    if 'body' in context:
        context['body'] = re.sub(r'href="([^"]+)\.rst(#[^"]*)?"', r'href="\1.html\2"', context['body'])

def setup(app):
    # Fix for 'make html'
    app.connect('html-page-context', fix_html_links)

# Project information
project = 'microG unofficial installer'
author = 'ale5000'
copyright = '2016-2019, 2021-%Y ale5000'
release = get_version()
version = release

revision = get_revision()
if revision:
    copyright += f" | Revision: {revision}"

# General configuration
needs_sphinx = '8.1'
extensions = [
    'sphinx_rtd_theme'
]

# Options for highlighting
highlight_language = 'sh'

# Options for markup
rst_epilog = f"""
.. |release| replace:: v{release}
"""

# Options for source files
master_doc = 'index'
source_suffix = {
    '.rst': 'restructuredtext'
}

# Options for HTML output
html_theme = 'sphinx_rtd_theme'
html_context = {
    'display_github': True,
    'github_user': 'micro5k',
    'github_repo': 'microg-unofficial-installer',
    'github_version': 'main',
    'conf_py_path': '/docs/'
}
