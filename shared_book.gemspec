# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{shared_book}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matthew Nielsen"]
  s.date = %q{2010-11-08}
  s.description = %q{A Ruby Gem to connect to the SharedBook.com publishing API.

This version provides 1:1 method call structure to the SharedBook rest-like API.}
  s.email = ["xunker@pyxidis.org"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.rdoc", "Rakefile", "lib/shared_book.rb", "script/console", "script/destroy", "script/generate", "spec/shared_book_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "tasks/rspec.rake"]
  s.homepage = %q{http://github.com/xunker/shared_book}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{shared_book}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{A Ruby Gem to connect to the SharedBook.com publishing API}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_development_dependency(%q<hoe>, [">= 2.6.1"])
    else
      s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_dependency(%q<hoe>, [">= 2.6.1"])
    end
  else
    s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
    s.add_dependency(%q<hoe>, [">= 2.6.1"])
  end
end
