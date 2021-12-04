# SPDX-FileCopyrightText: Copyright (C) 2016-2019, 2021 ale5000
# SPDX-License-Identifier: CC0-1.0
# SPDX-FileType: SOURCE

require 'codecov'
require 'simplecov'

SimpleCov.formatter = Codecov::SimpleCov::Formatter
SimpleCov.add_filter 'gradlew'
