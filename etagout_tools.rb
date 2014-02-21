#!/usr/bin/env ruby
require 'rubygems'
require 'thor'

class EtagoutTools < Thor

  desc 'sql_go', 'Add GO statements after the specified number of lines to avoid memory problem'
  option :file, :aliases => :f, :required => true, :desc => 'The path of the SQL file'
  option :number_of_lines, :aliases => :n, :desc => 'The number of lines after which to insert a GO'
  def sql_go
    number_of_lines = options.number_of_lines.to_i || 50
    sql_block = []
    File.open(options.file, 'r') do |f|
      while (line = f.gets)
        sql_block << line
        if sql_block.length == number_of_lines
          insert_go_after sql_block
          sql_block = []
        end
      end
    end
    insert_go_after sql_block
  end

private
  def insert_go_after(text)
    STDOUT.puts text
    STDOUT.puts 'GO'
  end

end

EtagoutTools.start