require './lib/vines/version'

Gem::Specification.new do |s|
  s.name         = "diaspora-vines"
  s.version      = Vines::VERSION
  s.summary      = %q[Diaspora-vines is a Vines fork build for diaspora integration.]
  s.description  = %q[Diaspora-vines is a Vines fork build for diaspora integration. DO NOT use it unless you know what you are doing!]

  s.authors      = ['David Graham','Lukas Matt']
  s.email        = ['david@negativecode.com','lukas@zauberstuhl.de']
  s.homepage     = 'https://diasporafoundation.org'
  s.license      = 'MIT'

  s.files        = Dir['[A-Z]*', 'vines.gemspec', '{bin,lib,conf,web}/**/*'] - ['Gemfile.lock']
  s.test_files   = Dir['test/**/*']
  s.executables  = %w[vines]
  s.require_path = 'lib'

  s.add_dependency 'bcrypt', '~> 3.1'
  s.add_dependency 'em-hiredis', '~> 0.3.0'
  s.add_dependency 'eventmachine', '>= 1.0.5', '< 1.1'
  s.add_dependency 'http_parser.rb', '~> 0.6'
  s.add_dependency 'nokogiri', '~> 1.6'
  s.add_dependency 'activerecord', '~> 4.1'


  s.add_development_dependency 'pronto', '~> 0.4.2'
  s.add_development_dependency 'pronto-rubocop', '~> 0.4.4'
  s.add_development_dependency 'rails', '~> 4.1'
  s.add_development_dependency 'sqlite3', '~> 1.3.9'
  s.add_development_dependency 'minitest', '~> 5.8'
  s.add_development_dependency 'rake', '~> 10.3'

  s.required_ruby_version = '>= 1.9.3'
end
