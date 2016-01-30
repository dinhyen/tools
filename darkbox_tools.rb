#!/usr/bin/env ruby
require 'rubygems'
require 'thor'
require 'yaml'

class DarkboxTools < Thor
  desc 'img_gen', 'Read images from directories append markdown based on template to blog posts'
  option :template, :aliases => :t, :required => true, :desc => 'The path of the template file to use'
  option :file, :aliases => :f, :required => true, :desc => 'Input YAML mapping blog postfile name to image folder name'
  option :lower, :aliases => :l, :desc => 'Use lowercase file names'
  # option :ext, :alias => '-e', :default => 'markdown', :desc => 'Markdown file extension'
  # option :out, :alias => '-o', :desc => 'Directory in which to write generate markdown files'
  option :silent, :aliases => :s, :type => :boolean, :default => false, :desc => 'Write run time info to console'
  def img_gen()
    msg = []
    input = load_yaml(options.file)

    post_path = File.expand_path(input['post_path']) || '.'
    img_path = File.expand_path(input['img_path']) || '.'

    list = input['content']
    list.reject! { |post, dir| dir.nil? }
    
    # append path to post and dir
    # list = list.inject({}) do |h, (post, img_dir)|
    #   h[File.join(post_path, post)] = File.join(img_path, img_dir)
    #   h
    # end

    template = File.read(options.template)

    list.each do |post, img_dir|
      full_post = File.join post_path, post
      full_img_dir = File.join img_path, img_dir
      full_thumb_dir = File.join full_img_dir, 'thumbs'

      msg << "#{post}"
      msg << "... #{img_dir}"

      html = []
      should_process = Dir.exists?(full_thumb_dir) # Only add template if we have thumbnails
      if should_process
        imgs = Dir.entries(full_thumb_dir)
        imgs = imgs.select { |img| full_img = File.join(full_img_dir, img); File.file?(full_img) }
        imgs.each do |img|
          img.downcase! if options.lower
          html << template.gsub(/\{\{dir\}\}/, img_dir).gsub(/\{\{file\}\}/, img)
        end
        str = []
        File.open(full_post, 'a') do |f|
          f << html_string(html)
        end
        msg << "...... #{imgs.size} images"
      else
        msg << "...... Skipping, no thumbnails detected"
      end
    end
    msg << "#{list.size} entries"
    log msg.join("\n")
  end

  desc 'img_bind', 'Populate template from file containing image file names and print to stdout'
  option :template, :aliases => :t, :required => true, :desc => 'The path of the template file to use'
  option :file, :aliases => :f, :required => true, :desc => 'File containing image file names, one per line'
  option :dir, :aliases => :d, :required => true, :desc => 'Image directory relative to /gallery in URL'
  option :lower, :aliases => :l, :desc => 'Use lowercase file names'
  # option :ext, :alias => '-e', :default => 'markdown', :desc => 'Markdown file extension'
  # option :out, :alias => '-o', :desc => 'Directory in which to write generate markdown files'
  option :silent, :aliases => :s, :type => :boolean, :default => false, :desc => 'Write run time info to console'
  def img_bind()
    template = File.read(options.template)

    html = []
    f = File.open(options.file, 'r')
    f.each_line do |img|
      img.strip!
      html << template.gsub(/\{\{dir\}\}/, options.dir).gsub(/\{\{file\}\}/, img)
    end
    puts html_string(html)
  end

private

  def html_string(img_html)
    str = []
    str << '<!-- Darkbox -->'
    str << '<div class="darkbox">'
    str << img_html.join
    str << '</div>'
    str << '<!-- End darkbox -->'
    str.join("\n")
  end

  def load_yaml(file)
    YAML.load_file(file)
  end

  def log(msg)
    STDOUT.puts msg unless options.silent
  end

end

DarkboxTools.start