#
# Author:: Sergio Rubio (<rubiojr@frameos.org>)
# Copyright:: Sergio Rubio (c) 2011
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'
require 'fog'
require 'net/ssh'
require 'net/scp'
require 'alchemist'

class Chef
  class Knife
    module KVMBase

      # :nodoc:
      # Would prefer to do this in a rational way, but can't be done b/c of
      # Mixlib::CLI's design :(
      def self.included(includer)
        includer.class_eval do

          deps do
            require 'net/ssh/multi'
            require 'readline'
            require 'chef/json_compat'
            require 'terminal-table/import'
          end

          option :kvm_password,
            :long => "--kvm-password PASSWORD",
            :description => "Your KVM password",
            :proc => Proc.new { |key| Chef::Config[:knife][:kvm_password] = key }

          option :kvm_username,
            :long => "--kvm-username USERNAME",
            :default => "root",
            :description => "Your KVM username (default 'root')",
            :proc => Proc.new { |username| Chef::Config[:knife][:kvm_username] = (username || 'root') }

          option :kvm_host,
            :long => "--kvm-host ADDRESS",
            :description => "Your KVM host address",
            :default => "127.0.0.1",
            :proc => Proc.new { |host| Chef::Config[:knife][:kvm_host] = host }

          option :libvirt_protocol,
            :long => "--libvirt-protocol PROTO",
            :description => "Libvirt connection protocol (default SSH)",
            :default => "ssh"
        end
      end

      def connection
        Chef::Config[:knife][:kvm_username] = 'root' if not Chef::Config[:knife][:kvm_username]
        if not @connection
          host = Chef::Config[:knife][:kvm_host] || '127.0.0.1'
          username = Chef::Config[:knife][:kvm_username]
          password = Chef::Config[:knife][:kvm_password]
          libvirt_uri = "qemu+#{config[:libvirt_protocol]}://#{username}@#{host}/system"
          ui.info "#{ui.color("Connecting to KVM host #{config[:kvm_host]} (#{config[:libvirt_protocol]})... ", :magenta)}"
          @connection = ::Fog::Compute.new :provider => 'libvirt',
                                         :libvirt_uri => libvirt_uri,
                                         :libvirt_ip_command => "virt-cat -d $server_name /tmp/ip-info 2> /dev/null |grep -v 127.0.0.1"
        else
          @connection
        end
      end

      def upload_file(source, dest, print_progress = true)
        Net::SSH.start(config[:kvm_host], config[:kvm_username], :password => config[:kvm_password]) do |ssh|
          puts "Uploading file... (#{File.basename(source)})"
          ssh.scp.upload!(source, dest) do |ch, name, sent, total|
            if print_progress
              print "\rProgress: #{(sent.to_f * 100 / total.to_f).to_i}% completed"
            end
          end
        end
        puts if print_progress
      end

      #
      # This mmight work only for Ubuntu
      # Directory: /etc/libvirt/qemu/autostart/ needs to be writable by kvm_username
      #
      def make_vm_autostart(name)
        Net::SSH.start(config[:kvm_host], config[:kvm_username], :password => config[:kvm_password]) do |ssh|
          puts "Making VM: #{name} autostart after machine shutdown."
          ssh.exec("ln -sf /etc/libvirt/qemu/#{name}.xml /etc/libvirt/qemu/autostart/#{name}.xml")
        end
        puts if print_progress
      end

      #
      # Download file from URL and saves it in iso_path
      # Directory: iso_path needs to be writable by kvm_username
      #
      def download_file(url, iso_path)
        Net::SSH.start(config[:kvm_host], config[:kvm_username], :password => config[:kvm_password]) do |ssh|
          puts "Making VM: #{name} autostart after machine shutdown."
          ssh.exec("curl #{url} > #{iso_path}")
        end
      end

      def locate_config_value(key)
        key = key.to_sym
        Chef::Config[:knife][key] || config[key]
      end

    end
  end
end


