# simplecov_helper.rb
require 'simplecov'

SimpleCov.enable_coverage :branch
SimpleCov.minimum_coverage 85
SimpleCov.use_merging true

SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter]

# Good defaults for Rails apps
SimpleCov.start 'rails' do
  add_filter '/config/'
  add_filter '/spec/'
  add_filter '/features/'
end
