#!/usr/bin/env ruby
# -*- coding: utf-8; mode: ruby; frozen_string_literal: true -*-
# SPDX-FileCopyrightText: NONE
# SPDX-License-Identifier: CC0-1.0

require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.configure do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::CoberturaFormatter, # For Codecov / Codacy
    SimpleCov::Formatter::JSONFormatter       # For SonarQube
  ])

  skip 'gradlew'
end
