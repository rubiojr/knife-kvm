# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "knife-kvm/version"

Gem::Specification.new do |s|
  s.name        = "knife-kvm"
  s.version     = Knife::KVM::VERSION
  s.has_rdoc = true
  s.authors     = ["Sergio Rubio"]
  s.email       = ["rubiojr@frameos.org","rubiojr@frameos.org"]
  s.homepage = "http://github.com/rubiojr/knife-kvm"
  s.summary = "KVM Support for Chef's Knife Command"
  s.description = s.summary
  s.extra_rdoc_files = ["README.rdoc", "LICENSE" ]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.add_dependency "fog", ">= 1.1.2"
  s.add_dependency "celluloid", ">= 0.9"
  s.add_dependency "popen4"
  s.add_dependency "terminal-table"
  s.add_dependency "alchemist"
  s.add_dependency "chef", ">= 0.10"
  s.add_development_dependency('rake')
  s.require_paths = ["lib"]

end
