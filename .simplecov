#!/usr/bin/env ruby
# -*- coding: utf-8; mode: ruby; frozen_string_literal: true -*-
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

require 'simplecov'
require 'simplecov-lcov'

SimpleCov.configure do
  formatter SimpleCov::Formatter::LcovFormatter
  add_filter 'gradlew'
end
