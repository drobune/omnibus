require 'ohai'
o = Ohai::System.new
o.require_plugin('os')
o.require_plugin('platform')
o.require_plugin('linux/cpu') if o.os == 'linux'
OHAI = o

require 'omnibus/library'
require 'omnibus/reports'
require 'omnibus/config'
require 'omnibus/software'
require 'omnibus/project'
require 'omnibus/fetchers'
require 'omnibus/s3_cacher'
require 'omnibus/s3_tasks'
require 'omnibus/health_check'
require 'omnibus/clean_tasks'

module Omnibus

  def self.root=(root)
    @root = root
  end

  def self.root
    @root
  end

  def self.build_version
    @build_version ||= begin
                         git_cmd = "git describe"
                         shell = Mixlib::ShellOut.new(git_cmd,
                                                      :cwd => Omnibus.root)
                         shell.run_command
                         shell.error!
                         shell.stdout
                       end
  end

  def self.gem_root=(root)
    @gem_root = root
  end

  def self.gem_root
    @gem_root
  end

  def self.setup(options = {})
    self.root = Dir.pwd
    self.gem_root = File.expand_path("../../", __FILE__)
    load_config
    yield self if block_given?
    # Load core software tasks
    software "#{gem_root}/config/software/*.rb" unless options[:no_core_software]
  end

  def self.config_path
    File.expand_path("omnibus.rb", root)
  end

  def self.load_config
    if File.exist?(config_path)
      TOPLEVEL_BINDING.eval(IO.read(config_path))
    else
      puts("No config file found in #{config_path}, exiting.")
      exit 1
    end
  end

  #--
  # Extra indirection so we don't need the Rake::DSL in the Omnibus module
  module Loader
    extend Rake::DSL

    def self.software(*path_specs)
      FileList[*path_specs].each do |f|
        s = Omnibus::Software.load(f)
        Omnibus.component_added(s)
        s
      end
    end

    def self.projects(*path_specs)
      FileList[*path_specs].each do |f|
        Omnibus::Project.load(f)
      end
    end
  end

  def self.software(*path_specs)
    Loader.software(*path_specs)
  end

  def self.projects(*path_specs)
    Loader.projects(*path_specs)
  end
end

