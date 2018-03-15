#!/usr/bin/env ruby
require 'rubygems'
require 'thor'
require 'yaml'

class FileTools < Thor
  desc 'nodash', 'Replace dash from file names'
  def nodash
    files = Dir.entries(".")
    files.each do |f|
      if f =~ /--/
        new_f = f.gsub /\-\-/, ''
        system "mv -- #{f} #{new_f}"
      end
    end
  end

  desc 'to_markdown', 'Replace .html markdown extension with .markdown'
  # option :silent, :aliases => :s, :type => :boolean, :default => false, :desc => 'Write run time info to console'
  def to_markdown
    files = Dir.glob('**/*.html')
    files.each do |f|
      new_f = f.gsub 'html', 'markdown'
      system "mv #{f} #{new_f}" if File.file? f
    end
  end

  desc 'markdown_to_index', 'Replace xxx.markdown with xxx/index.markdown'
  def markdown_to_index
    files = Dir.glob('**/*.markdown')
    files.each do |f|
      dir = File.dirname f
      file = File.basename f, '.*'
      ext = File.extname f
      if file != 'index'
        full_dir = File.join(dir, file)
        Dir.mkdir "#{full_dir}"
        system "mv #{f} #{full_dir}/index.markdown"
      end
    end
  end

  desc 'img_gen', 'Read images from directories append markdown based on template to blog posts'
  option :template, :aliases => :t, :required => true, :desc => 'The path of the template file to use'
  option :file, :aliases => :f, :required => true, :desc => 'Input YAML mapping blog postfile name to image folder name'
  # option :ext, :alias => '-e', :default => 'markdown', :desc => 'Markdown file extension'
  # option :out, :alias => '-o', :desc => 'Directory in which to write generate markdown files'
  option :lowercase, :aliases => :l, :type => :boolean, :default => false, :desc => 'Convert file name to lower case'
  option :silent, :aliases => :s, :type => :boolean, :default => false, :desc => 'Write run time info to console'
  def img_gen
    output = []
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

      output << "#{post}"
      output << "... #{img_dir}"

      html = []
      should_process = Dir.exists?(full_thumb_dir) # Only add template if we have thumbnails
      if should_process
        imgs = Dir.entries(full_thumb_dir)
        imgs = imgs.select { |img| full_img = File.join(full_img_dir, img); File.file?(full_img) }
        imgs.each do |img|
          img.downcase! if options[:lowercase]
          html << template.gsub(/\{\{dir\}\}/, img_dir).gsub(/\{\{file\}\}/, img)
        end
        str = []
        File.open(full_post, 'a') do |f|
          str << '<!-- Darkbox -->'
          str << '<div class="darkbox">'
          str << html.join
          str << '</div>'
          str << '<!-- End darkbox -->'
          f << str.join("\n")
        end
        output << "...... #{imgs.size} images"
      else
        output << "...... Skipping, no thumbnails detected"
      end
    end
    output << "#{list.size} entries"
    log output.join("\n")
  end

  desc 'doc_gen', 'Read text files and append to markdown'
  option :file, :aliases => :f, :required => true, :desc => 'Input YAML containing paths and names of files'
  option :silent, :aliases => :s, :type => :boolean, :default => false, :desc => 'Write run time info to console'
  def doc_gen
    output = []
    input = load_yaml(options.file)

    post_path = File.expand_path(input['post_path']) || '.'
    txt_path = File.expand_path(input['content_path']) || '.'

    files = input['content']
    files.each do |file|
      file_parts = file.gsub('/index.markdown','').split('/')
      country = file_parts.first
      place = file_parts.last

      src_file = File.join(txt_path, place + '.txt')
      dest_file = File.join(post_path, file)

      unless File.exists?(src_file) and File.exists?(dest_file)
        output << 'source file missing or dest file missing'
        next
      end

      content = File.read(src_file)
      File.open(dest_file, 'a') do |outfile|
        outfile << content
      end

      output << "#{country} > #{place}"
      output << "... #{src_file} => #{dest_file}"
    end
    # log(input.inspect)
    log(output.join("\n"))
  end

  desc 'title_from_h1', 'Set title to <h1> content and remove <h1> in specified directory'
  def title_from_h1(dir)
    output = []
    output << "Processing #{dir}..."
    Dir.glob(File.join(dir, "**", "*.{markdown,md}")) do |file|
      output << "...#{file}"
      content = File.read(file)
      match = /title:(["\-\w ]+).*<h1>([^<]+)<\/h1>/m.match(content)
      if match
        content.gsub! /(?<=title:)["\-\w ]+/, " \"#{match[2]}\""  # update title
        content.gsub! /<h1>.*<\/h1>\s*/, ''                       # remove <h1> tag
        output << "...Replace #{match[1]} with \"#{match[2]}\""
        # output << content
        # output << match.inspect
      end
      File.open(file, 'w') do |outfile|
        outfile << content
      end
      
    end
    log(output.join("\n"))
  end

  desc 'config_from', 'Generate navigation YAML from directory'
  def config_from(dir)
    yaml = []

    country = File.basename(dir)
    yaml << write_node(1, country)

    entries = Dir.entries(dir)
    places = entries.reject { |e| e =~ /^\./}.select { |e| File.directory?(File.join(dir, e)) }#.map { |e| File.join(dir, e) }
    
    places.each do |place|
      place_path = File.join(dir, place)
      index_page = File.join(place_path, 'index.markdown')
      if File.exists?(index_page)
        content = File.read(index_page)
        title = /^title:\s*("?.*"?)\s*$/.match(content)[1]
        yaml << write_leaf(2, title, place)
      end
    end
    log(yaml.join("\n"))
  end
private

  def indent
    "  "
  end

  def write_node(level, name)
    "#{indent * level} #{name}:"
  end

  def write_leaf(level, name, value)
    output = []
    output << "#{indent * level}- name: #{name}"
    output << "#{indent * level}  url:  #{value}"
    output.join("\n")
  end

  def load_yaml(file)
    YAML.load_file(file)
  end

  def log(msg)
    STDOUT.puts msg unless options.silent
  end

end

FileTools.start