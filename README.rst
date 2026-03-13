###########################
microG unofficial installer
###########################
..
   SPDX-License-Identifier: GPL-3.0-or-later
   SPDX-FileType: DOCUMENTATION

:Author: `ale5000 <https://github.com/ale5000-git>`_
:License: `GPLv3.0 or later <./LICENSE.rst>`_

.. image:: https://app.readthedocs.org/projects/microg-unofficial-installer/badge/?version=latest
   :alt: Documentation status
   :target: https://microg-unofficial-installer.readthedocs.io/en/latest/

.. image:: https://codecov.io/gh/micro5k/microg-unofficial-installer/branch/main/graph/badge.svg
   :alt: Coverage
   :target: https://codecov.io/gh/micro5k/microg-unofficial-installer

.. image:: https://api.reuse.software/badge/github.com/micro5k/microg-unofficial-installer
   :alt: REUSE status
   :target: https://api.reuse.software/info/github.com/micro5k/microg-unofficial-installer


Description
===========
microG unofficial installer is a flashable zip created by ale5000 for a simple installation of microG on Android from 2.2 to 16.
No root wizardry required — just flash and go. ✨

This project is available on GitHub_, on GitLab_, as well as on XDA_.

.. _GitHub: https://github.com/micro5k/microg-unofficial-installer
.. _GitLab: https://gitlab.com/micro5k/microg-unofficial-installer
.. _XDA: https://xdaforums.com/t/3432360/

**IMPORTANT:** In addition to the normal installation as a pure flashable zip, there are plans for the future (but not in the short term) to also support the installation as a *Magisk* module.

Although you may find various references to *Magisk* in the code, support is **NOT** yet ready.


Download
========
Grab the latest stable release or, if you like to live dangerously, the nightly build.
The badges below show the current version and download statistics.

.. image:: https://img.shields.io/github/v/release/micro5k/microg-unofficial-installer.svg?cacheSeconds=3600
   :alt: GitHub latest release
   :target: `download`_

.. image:: https://img.shields.io/github/downloads/micro5k/microg-unofficial-installer/total.svg?cacheSeconds=3600
   :alt: Total OSS downloads
   :target: `download`_

.. image:: https://img.shields.io/github/downloads/micro5k/microg-unofficial-installer/latest/total.svg?cacheSeconds=3600
   :alt: Downloads of the latest OSS release
   :target: `download`_

.. image:: https://img.shields.io/github/downloads/micro5k/microg-unofficial-installer/nightly/total.svg?cacheSeconds=600
   :alt: Downloads of the latest OSS nightly
   :target: `download`_

`Download instructions <./docs/INSTRUCTIONS.rst>`_ *(reading them is optional, but so is a successful installation)*


Code analysis
=============
Yes, the code is actually linted. No, it wasn't always pretty. Yes, it's better now. 🔍

CI pipelines run on every push to keep the build healthy — the code-lint workflow checks style and correctness, while the nightly workflow validates a full automated build.
In addition, SonarCloud, Codacy, and CodeFactor provide continuous code quality analysis from multiple angles, because one linter is never enough.

.. image:: https://github.com/micro5k/microg-unofficial-installer/actions/workflows/code-lint.yml/badge.svg
   :alt: Code lint workflow
   :target: https://github.com/micro5k/microg-unofficial-installer/actions/workflows/code-lint.yml

.. image:: https://github.com/micro5k/microg-unofficial-installer/actions/workflows/auto-nightly.yml/badge.svg
   :alt: Nightly workflow
   :target: https://github.com/micro5k/microg-unofficial-installer/actions/workflows/auto-nightly.yml

.. image:: https://sonarcloud.io/api/project_badges/measure?project=micro5k_microg-unofficial-installer&metric=reliability_rating
   :alt: SonarQube badge
   :target: https://sonarcloud.io/summary/new_code?id=micro5k_microg-unofficial-installer

.. image:: https://app.codacy.com/project/badge/Grade/e372a72b55f54bcf80966c8266e3e7fb
   :alt: Codacy badge
   :target: https://app.codacy.com/gh/micro5k/microg-unofficial-installer/dashboard

.. image:: https://www.codefactor.io/repository/github/micro5k/microg-unofficial-installer/badge
   :alt: CodeFactor badge
   :target: https://www.codefactor.io/repository/github/micro5k/microg-unofficial-installer


Contributing
============
If you want to improve the project, please review our `contributing guidelines <./docs/CONTRIBUTING.rst>`_.

We are grateful for all our contributors! 🎉
Seriously — every bug fix, improvement, or creative complaint has made this better.

Please check the `contributors list <./docs/CONTRIBUTORS.md>`_ for more details.

*(Even fixing a typo counts. Probably. We'll review it very carefully either way.)*


Donations
=========
.. image:: https://img.shields.io/badge/Donate-FFF000?logo=ko-fi&logoSize=auto&logoColor=black&cacheSeconds=21600
   :alt: Support this project
   :target: ./docs/DONATE.rst

I maintain this project on my own in my spare time — the finite, precious kind that competes with sleep, meals eaten while staring at a terminal, and the occasional social obligation.

If it's saved you time, frustration, or a trip to the Google ecosystem, please consider supporting its development!

Wondering how? Check out all the ways to `fuel this project <./docs/DONATE.rst>`_ — coffee, kind words, or cold hard crypto, it's all welcome.


Copyright
=========
© 2016-2019, 2021-2026 ale5000
