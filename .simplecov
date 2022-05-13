# SPDX-FileCopyrightText: none
# SPDX-License-Identifier: CC0-1.0
# SPDX-FileType: SOURCE

require 'codecov'
require 'simplecov'

SimpleCov.formatter Codecov::SimpleCov::Formatter
SimpleCov.add_filter 'gradlew'
