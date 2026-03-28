#!/usr/bin/env python
# -*- coding: utf-8 -*-
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

"""Configuration file for the Sphinx documentation builder.

This module contains the configuration settings for generating documentation
using Sphinx. For a full list of built-in configuration values, see:
https://www.sphinx-doc.org/en/master/usage/configuration.html
"""

import datetime
import os
import subprocess  # nosec B404
import sys

from docutils import nodes
from sphinx import addnodes
from sphinx.util import logging

try:
    from typing import TYPE_CHECKING

    if TYPE_CHECKING:
        from typing import IO, Any, Callable, Final  # noqa: F401

        from sphinx.application import Sphinx  # noqa: F401
except ImportError:
    pass

try:
    from subprocess import DEVNULL as _TMP_DEVNULL

    _DEVNULL = _TMP_DEVNULL  # type: int | IO[Any]
except ImportError:
    import atexit

    _DEVNULL = open(os.devnull, "wb")  # noqa: SIM115
    atexit.register(_DEVNULL.close)

try:
    # Attempt to use the native shutil.which for Python 3.3+
    from shutil import which as _tmp_shutil_which

    _shutil_which = _tmp_shutil_which  # type: Callable[..., str | None] | None
except ImportError:
    _shutil_which = None

try:
    from datetime import timezone as _tmp_tz

    _UTC = _tmp_tz.utc  # type: datetime.tzinfo
except ImportError:

    class TimezoneUTC(datetime.tzinfo):
        """UTC implementation for compatibility with legacy Python versions.

        Ensures 'aware' datetime objects can be used for UTC time.
        """

        def utcoffset(self, _dt):
            # type: (datetime.datetime | None) -> datetime.timedelta
            return datetime.timedelta(0)

        def dst(self, _dt):
            # type: (datetime.datetime | None) -> datetime.timedelta
            return datetime.timedelta(0)

        def tzname(self, _dt):
            # type: (datetime.datetime | None) -> str
            return "UTC"

    _UTC = TimezoneUTC()

logger = logging.getLogger(__name__)  # type: Final

_DOCS_DIR = os.path.dirname(os.path.abspath(__file__))  # type: Final
_REPO_ROOT = os.path.normpath(os.path.join(_DOCS_DIR, ".."))  # type: Final


def which(cmd, mode=os.F_OK | os.X_OK, path=None):
    # type: (str, int, str | None) -> str | None
    """Find the full path to an executable file, mimicking shutil.which.

    :param cmd: The command to search for
    :param mode: The permission mode to check (default is exists and executable)
    :param path: Custom search path (defaults to the PATH environment variable)
    :return: Full path to the executable or None if not found
    """
    if _shutil_which:
        return _shutil_which(cmd, mode, path)

    # If cmd contains a path component, check it directly
    if os.path.dirname(cmd):
        if os.access(cmd, mode) and os.path.isfile(cmd):
            return cmd
        return None

    if path is None:
        path = os.environ.get("PATH", os.defpath)
    if not path:
        return None

    exts = ("", ".exe") if sys.platform == "win32" else ("",)  # type: Final

    for directory in path.split(os.pathsep):
        full_prefix = os.path.join(os.path.expanduser(directory), cmd)
        for ext in exts:
            candidate = full_prefix + ext
            if os.access(candidate, mode) and os.path.isfile(candidate):
                return candidate

    return None


def get_version():
    # type: () -> str

    props_path = os.path.join(_REPO_ROOT, "zip-content", "module.prop")

    if os.path.exists(props_path):
        with open(props_path) as f:
            for line in f:
                if line.startswith("version="):
                    return line.replace("version=", "").lstrip("v").strip()
    return "0.0.0-unknown"


def get_revision():
    # type: () -> str | None

    # Use Read the Docs environment variables if available
    git_rev = os.environ.get("READTHEDOCS_GIT_COMMIT_HASH", "")[:8] or None
    git_id = os.environ.get("READTHEDOCS_GIT_IDENTIFIER")
    if git_rev:
        return "{0} ({1})".format(git_rev, git_id) if git_id else git_rev

    # Fallback to Git CLI
    git = which("git")  # type: Final
    if not git:
        return None
    try:
        return (
            # Safe: uses list-based arguments (no shell) to prevent injection
            subprocess.check_output(  # nosec B603 # noqa: S603
                [git, "rev-parse", "--short=8", "HEAD"],
                stderr=_DEVNULL,
            )
            .decode("utf-8")
            .strip()
        )
    except Exception:
        return None


def _fix_shdoc_refs(_app, doctree):
    # type: (Sphinx, nodes.document) -> None

    for node in doctree.findall(addnodes.pending_xref):
        if node.get("reftype") != "myst":
            continue

        target = node.get("reftarget", "")
        if (
            node.get("refexplicit")
            and not node.get("refuri")
            and target
            and "/" not in target
        ):
            new_target = target.replace("_", "-")
            if new_target != target:
                node["reftarget"] = new_target
                doc = node.get("refdoc", "unknown")
                logger.info(
                    "[DEBUG] Fixed target: %s -> %s in %s",
                    target,
                    new_target,
                    doc,
                )


def _transform_rst_links(app, doctree):
    # type: (Sphinx, nodes.document) -> None
    """Convert internal .rst file links to Sphinx cross-references.

    Automatically converts internal .rst file links to Sphinx cross-references
    (:doc: or :ref:), enabling validation and proper path resolution.
    """
    docname = app.env.docname  # type: Final
    # Traverse only reference nodes that have a "refuri" attribute
    for node in doctree.findall(nodes.reference):
        uri = node.get("refuri", "")
        if ".rst" not in uri or uri.startswith(("http", "mailto:", "//")):
            continue

        parts = uri.split("#", 1)
        has_anchor = len(parts) > 1
        reftype = "ref" if has_anchor else "doc"
        reftarget = (
            parts[1]
            if has_anchor
            else (parts[0][:-4] if parts[0].endswith(".rst") else parts[0])
        )
        logger.info(
            "[DEBUG] Converting %s -> :%s:`%s`",
            uri,
            reftype,
            reftarget,
        )

        # Create pending_xref node which Sphinx resolves during build phase
        new_node = addnodes.pending_xref(
            "",
            reftype=reftype,
            refdomain="std",
            reftarget=reftarget,
            refdoc=docname,
            refwarn=True,
            refexplicit=True,
        )
        # Transfer children (the link text) and replace the original node
        new_node.extend(node.children)
        node.replace_self(new_node)


def setup(app):
    # type: (Sphinx) -> dict[str, Any]
    """Connect custom logic to the Sphinx build process.

    This function tells Sphinx to run specific functions (hooks)
    at the right time during documentation generation.
    """
    app.connect("doctree-read", _fix_shdoc_refs)
    app.connect("doctree-read", _transform_rst_links)
    return {
        "version": "0.1",
        "parallel_read_safe": True,
        "parallel_write_safe": True,
    }


# Project information
project = "microG unofficial installer"
author = "ale5000"
project_copyright = "2016-2019, 2021-{0} ale5000".format(
    datetime.datetime.now(_UTC).strftime("%Y"),
)
release = get_version()
version = release

revision = get_revision()
if revision:
    project_copyright += " | Revision: {0}".format(revision)

# General configuration
needs_sphinx = "1.8"
extensions = ["sphinx_rtd_theme", "myst_parser"]

# Options for highlighting
highlight_language = "sh"

# Options for internationalisation
language = "en"

# Options for markup
rst_epilog = "\n.. |release| replace:: v{0}\n".format(release)

# Options for source files
exclude_patterns = ["CONTRIBUTORS.md"]
master_doc = "index"
source_suffix = {".rst": "restructuredtext", ".md": "markdown"}

# Options for warning control

# Links are working using implicit references but MyST still emit warnings
# instead of verify
suppress_warnings = ["myst.xref_missing"]  # TODO: Find an alternative way

# Options for HTML output
html_theme = "sphinx_rtd_theme"
html_context = {
    "display_github": True,
    "github_user": "micro5k",
    "github_repo": "microg-unofficial-installer",
    "github_version": "main",
    "conf_py_path": "/docs/",
}

# Options for LaTeX output (e.g., PDF)
latex_elements = {}

# The "openany" option allows chapters to begin on the next available page;
# this prevents unwanted blank pages by allowing starts on even or odd pages
latex_elements.update({"extraclassoptions": "openany"})
