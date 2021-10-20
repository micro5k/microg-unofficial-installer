require 'codecov'
require 'simplecov'

SimpleCov.formatter = Codecov::SimpleCov::Formatter
SimpleCov.add_filter 'gradlew'
