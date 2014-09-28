#!/usr/bin/env ruby
# encoding: UTF-8

# dead simple ssh connection manager
class Application
  require 'highline/import'

  VERSION = '0.1.4'

  # Core methods
  class Foundation
    # SSH methods
    module SSH
      def self.connect(server)
        exec "ssh #{server}"
      end
    end

    # preparation and setting the configuration file
    class Config
      PATH = "#{ENV['HOME']}/.ssh/config"
      OPTIONS = %w(hidden)

      # prepare config
      def initialize
        # load ssh config
        new = File.readlines(PATH).map(&:split)
        @data = construct new
      rescue => err
        abort "Error: config is invalid.\nReason: #{err}"
      end

      def construct(raw)
        container = []
        raw.each_with_index do |block, index|
          next if block.empty? || comment?(block)
          if block[0] == 'Host'
            container << {}
            container.last.merge!(options: options(raw, index))
          end
          container.last.merge!(block[0].downcase.to_sym => block[1]) if defined? container
        end
        container
      end

      # parse inline options passed in comments of specific block
      def options(raw, index)
        @prev_index = 0 unless defined? @prev_index
        options = {}

        index = index-1
        # catch options between range
        raw[@prev_index..index].each do |opt|
          if comment?(opt) && option?(opt)
            options.merge!(opt[1].downcase.to_sym => true)
          end
        end
        @prev_index = index
        options
      end

      def option?(block)
        OPTIONS.include?(block[1])
      end

      # block is comment?
      def comment?(block)
        true if block[0] == '#'
      end

      # determine if config exist
      def exist?
        # ssh configuration file
        if File.exist?(PATH)
          return true
        else
          abort "Error: no configuration file is found.\nExpected path: #{path}"
        end
      end

      attr_reader :data
      private :exist?, :comment?, :option?, :construct, :options
    end
  end

  # CLI interface for SSH manager
  class Interface < Foundation
    def initialize
      config = Config.new
      show_menu config.data, 'host'

      # ignore errors when use ctrl-c or ctrl-d
    rescue SystemExit, Interrupt, EOFError
      puts "\nexiting..."
    end

    def show_menu(list, title)
      t = title.to_sym
      proposal = 'Please choose the server which you would like to connect?'
      choose do |menu|
        menu.prompt = proposal
        list.each do |item|
          unless item[:options][:hidden]
            menu.choice(item[t]) { SSH.connect item[t] }
          end
        end
      end
    end
  end
  Interface.new
end
