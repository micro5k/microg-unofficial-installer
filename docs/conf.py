#!/usr/bin/env python
# -*- coding: utf-8 -*-
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

# Configuration file for the Sphinx documentation builder
# For the full list of built-in configuration values, see the documentation: https://www.sphinx-doc.org/en/master/usage/configuration.html

import os
import subprocess

from docutils import nodes
from sphinx import addnodes
from sphinx.util import logging


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


def transform_rst_links(app, doctree):
    """
    Automatically converts internal .rst file links to Sphinx cross-references
    (:doc: or :ref:), enabling validation and proper path resolution.
    """

    docname = app.env.docname
    # Traverse only reference nodes that have a 'refuri' attribute
    for node in doctree.findall(nodes.reference):
        uri = node.get('refuri', '')
        if '.rst' not in uri or uri.startswith(('http', 'mailto:', '//')):
            continue

        parts = uri.split('#', 1)
        has_anchor = len(parts) > 1
        reftype = 'ref' if has_anchor else 'doc'
        reftarget = parts[1] if has_anchor else parts[0].removesuffix('.rst')
        logger.info(f"[DEBUG] Converting {uri} -> :{reftype}:`{reftarget}`")

        # Create pending_xref node which Sphinx resolves during build phase
        new_node = addnodes.pending_xref(
            '',
            reftype=reftype,
            refdomain='std',
            reftarget=reftarget,
            refdoc=docname,
            refwarn=True,
            refexplicit=True
        )
        # Transfer children (the link text) and replace the original node
        new_node.extend(node.children)
        node.replace_self(new_node)


def setup(app):
    # Hook to modify the document structure before rendering
    app.connect('doctree-read', transform_rst_links)
    return {
        'version': '0.1',
        'parallel_read_safe': True,
        'parallel_write_safe': True
    }


logger = logging.getLogger(__name__)

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

# Options for LaTeX output (e.g., PDF)
if 'latex_elements' not in locals():
    latex_elements = {}

# The 'openany' option allows chapters to begin on the next available page;
# this prevents unwanted blank pages by allowing starts on even or odd pages
latex_elements['extraclassoptions'] = (latex_elements.get('extraclassoptions', '') + ',openany').strip(',')
