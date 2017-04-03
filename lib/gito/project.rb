﻿require 'tmpdir'
require 'fileutils'
require 'uri'
require_relative './app_utils'
require 'pry'

class Project
  def initialize(url)
    @base_url = sanitize_url(url)
    @destination_dir = nil
    @destination = destination
    @project_type = :unknown
  end

  def sanitize_url(url)
    url = url.split('?').first
    url.chop! if url.end_with? '/'

    is_valid_url = url =~ /\A#{URI::regexp(['http', 'https'])}\z/ || url.include?('git@')

    unless is_valid_url

      valid_shortcut = url.split('/').size == 2

      if valid_shortcut
        url = 'https://github.com/' + url
      else
        url = nil
      end
    end
    url
  end

  def destination
    unless @base_url.include? 'github.com'
      return Digest::SHA256.hexdigest @base_url
    end

    stripped_url = @base_url.gsub('.git', '')
    stripped_url = stripped_url.gsub('.git', '')
    stripped_url = stripped_url.gsub('git@github.com:', '')
    stripped_url = stripped_url.gsub('https://github.com/', '')
    stripped_url.gsub('http://github.com/', '')

    stripped_url.gsub('/','-')
  end

  def change_directory
    temp_script_name = 'temp.sh'
    AppUtils::execute 'echo "cd '+@destination+'" > ' + temp_script_name
    AppUtils::execute '. '+temp_script_name
    AppUtils::execute 'rm -rf ' + temp_script_name
    puts Dir.pwd
  end

  def detect_project_type
    Dir.chdir @destination_dir

    type = :unknown

    if File.exist?('build.gradle')
      type = :gradle
    elsif File.exist?('package.json')
      type = :node
    elsif File.exist?('Gemfile')
      type = :ruby
    end
    type
  end

  def install_dependencies
    case @project_type
      when :gradle
        AppUtils::execute('./gradlew assemble')
      when :node
        AppUtils::execute('npm install')
      when :ruby
        AppUtils::execute('bundle install')
      else
        puts 'Unknown project type'
    end
  end

  def cloneable_url
    starts_with_git = @base_url.split(//).first(4).join.eql? 'git@'
    ends_with_git = @base_url.split(//).last(4).join.eql? '.git'

    # ends with git but doesnt start with git
    return @base_url if ends_with_git && !starts_with_git

    # ends with git but doesnt start with git
    return "#{@base_url}.git" if !ends_with_git && !starts_with_git

    @base_url
  end

  ##
  ## CLONE THE REPOSITORY
  ##
  def clone
    cloneable = cloneable_url

    @destination_dir = Dir.pwd + "/#{@destination}"

    if File.directory?(@destination_dir)
      puts 'The folder is not empty'
    else
      AppUtils.execute("git clone --depth 1 #{cloneable} #{@destination_dir}")
    end

    @destination_dir
  end

  def open_editor
    puts "opening editor"
  end

  def open_folder
    puts 'opening folder'
  end
end
