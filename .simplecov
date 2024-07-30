#!/usr/bin/env ruby
# -*- coding: utf-8; mode: ruby; frozen_string_literal: true -*-

# SPDX-FileCopyrightText: none
# SPDX-License-Identifier: CC0-1.0

require 'codecov'
require 'simplecov'

SimpleCov.configure do
  formatter Codecov::SimpleCov::Formatter
  add_filter 'gradlew'
end
