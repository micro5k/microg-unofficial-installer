#!/usr/bin/env ruby
# -*- coding: utf-8; mode: ruby; frozen_string_literal: true -*-

# SPDX-FileCopyrightText: none
# SPDX-License-Identifier: CC0-1.0

require 'simplecov'
require 'simplecov-lcov'
#require 'codecov' # Deprecated

SimpleCov.configure do
  formatter SimpleCov::Formatter::LcovFormatter
  #formatter Codecov::SimpleCov::Formatter # Deprecated
  add_filter 'gradlew'
end
