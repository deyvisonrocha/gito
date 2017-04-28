﻿require 'tmpdir'
require 'fileutils'
require 'uri'
require 'open-uri'
require 'json'
require_relative './app_utils'

class Project
  def initialize(url)
    @base_url = sanitize_url(url)
    @destination_dir = nil
    @destination = destination
    @detector_json_path = 'https://raw.githubusercontent.com/cesarferreira/gito/master/detector.json'
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
    stripped_url = @base_url.gsub('.git', '')

    if stripped_url.start_with?('http')
      stripped_url = stripped_url.split('/').last
    end

    if stripped_url.include?(':') && stripped_url.start_with?('git@')
      stripped_url = stripped_url.split(':').last.split('/').last
    end

    stripped_url
  end

  def change_directory
    short_path = @destination_dir.to_s.gsub(Dir.home, '~')

    puts "\n-------------------------------------------"
    puts "Please change directory"
    puts "cd #{short_path.yellow}"
    puts "-------------------------------------------\n\n"
  end

  def install_dependencies
    file  = open(@detector_json_path) {|f| f.read }
    types = JSON.parse(file)
    chosen = nil

    Dir.chdir(@destination_dir)

    types.each do |item|
      if File.exists? (item['file_requirement'])
        puts "\n😎  #{item['type']} detected...\n".yellow
        go_inside_and_run item['installation_command']
      end
    end
  end

  def retrieve_cloneable_url
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
  def clone(is_temp_folder=false, shell_copy=true)
    url = retrieve_cloneable_url

    unless is_temp_folder
      prefix = Dir.pwd + '/'
    else
      prefix = Dir.tmpdir + '/gito/'
    end

    @destination_dir = prefix + "#{@destination}"

    if File.directory?(@destination_dir)
      puts "\n🤔  The folder #{@destination_dir.green} is not empty...\n\n"
      go_inside_and_run "git reset --hard HEAD"
      go_inside_and_run "git pull"
    else
      puts "\n😙  Cloning #{url.green}...\n\n"
      shell_copy_string = shell_copy ? '--depth 1' : ''
      AppUtils.execute("git clone #{shell_copy_string} --recursive #{url} #{@destination_dir}")
    end

    @destination_dir
  end

  def open_editor(app)
    puts "\n😁‍  Opening editor...".yellow
    go_inside_and_run "#{app} ."
  end

  def open_folder
    puts "\n😳  Opening folder...".yellow
    go_inside_and_run 'open .'
  end

  def go_inside_and_run(command)
    Dir.chdir(@destination_dir) do
      AppUtils::execute command, false
    end
  end
end
