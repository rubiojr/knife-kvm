#
# Author:: Sergio Rubio (<rubiojr@frameos.org>)
# Copyright:: Copyright (c) 2011, Sergio Rubio
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

require 'chef/knife/kvm_base'

class Chef
  class Knife
    class KvmVmCreate < Knife

      include Knife::KVMBase

      deps do
        require 'readline'
        require 'alchemist'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
      end

      banner "knife kvm vm create (options)"

      option :vm_disk,
        :long => "--vm-disk FILE",
        :description => "The path to the QCOW2 disk file"

      option :vm_name,
        :long => "--vm-name NAME",
        :description => "The Virtual Machine name"
      
      option :pool,
        :long => "--pool NAME",
        :default => 'default',
        :description => "The Pool to use for the VM files (default: default)"
      
      option :os_type,
        :long => "--os-type NAME",
        :default => "hvm",
        :description => "The OS Type (default: hvm)"

      option :memory,
        :long => "--vm-memory MEM",
        :default => "512",
        :description => "The VM memory in MB (default: 512)"

      option :chef_node_name,
        :short => "-N NAME",
        :long => "--node-name NAME",
        :description => "The Chef node name for your new node"

      option :prerelease,
        :long => "--prerelease",
        :description => "Install the pre-release chef gems"

      option :bootstrap_version,
        :long => "--bootstrap-version VERSION",
        :description => "The version of Chef to install",
        :proc => Proc.new { |v| Chef::Config[:knife][:bootstrap_version] = v }

      option :distro,
        :short => "-d DISTRO",
        :long => "--distro DISTRO",
        :description => "Bootstrap a distro using a template; default is 'ubuntu10.04-gems'",
        :proc => Proc.new { |d| Chef::Config[:knife][:distro] = d },
        :default => "ubuntu10.04-gems"

      option :template_file,
        :long => "--template-file TEMPLATE",
        :description => "Full path to location of template to use",
        :proc => Proc.new { |t| Chef::Config[:knife][:template_file] = t },
        :default => false

      option :run_list,
        :short => "-r RUN_LIST",
        :long => "--run-list RUN_LIST",
        :description => "Comma separated list of roles/recipes to apply",
        :proc => lambda { |o| o.split(/[\s,]+/) },
        :default => []

      option :ssh_user,
        :short => "-x USERNAME",
        :long => "--ssh-user USERNAME",
        :description => "The ssh username; default is 'root'",
        :default => "root"
      
      option :ssh_password,
        :short => "-P PASSWORD",
        :long => "--ssh-password PASSWORD",
        :description => "The ssh password"

      option :identity_file,
        :short => "-i IDENTITY_FILE",
        :long => "--identity-file IDENTITY_FILE",
        :description => "The SSH identity file used for authentication"
      
      option :no_host_key_verify,
        :long => "--no-host-key-verify",
        :description => "Disable host key verification",
        :boolean => true,
        :default => false,
        :proc => Proc.new { true }
      
      option :network_interface,
        :long => "--network-interface type:name",
        :description => "The network interface description (default bridge:br0)",
        :default => "bridge:br0"
      

      def tcp_test_ssh(hostname)
        tcp_socket = TCPSocket.new(hostname, 22)
        readable = IO.select([tcp_socket], nil, nil, 5)
        if readable
          Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{tcp_socket.gets}")
          yield
          true
        else
          false
        end
      rescue Errno::ETIMEDOUT, Errno::EPERM
        false
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH
        sleep 2
        false
      ensure
        tcp_socket && tcp_socket.close
      end

      def run
        $stdout.sync = true

        unless config[:vm_disk]
          ui.error("You have not provided a valid QCOW2 file. (--vm-disk)")
          exit 1
        end
        
        if not File.exist?(config[:vm_disk])
          ui.error("Invalid QCOW2 disk file (--vm-disk)")
          exit 1
        end
        
        vm_name = config[:vm_name]
        if not vm_name
          ui.error("Invalid Virtual Machine name (--vm-name)")
          exit 1
        end

        pool = config[:pool]
        memory = config[:memory]
        vm_disk = config[:vm_disk]
        os_type =config[:os_type]
        destination_path = "/var/lib/libvirt/images/"

        #connection.remote_command "mkdir #{destination_path}"
        puts "#{ui.color("Creating VM... ", :magenta)}"
        net_type, net_if = config[:network_interface].split(':')
        vm = connection.servers.create :name => vm_name,
                          :volume_allocation => "#{File.size(vm_disk)/1024/1024}M",
                          :volume_capacity => '10G',
                          :volume_format_type => 'qcow2',
                          #:autostart => true, # Starting guest automatically
                          :volume_pool_name => pool,
                          :network_interface_type => net_type,
                          :memory_size => memory.to_i * 1024,
                          :network_bridge_name => net_if

        puts "#{ui.color("Importing VM disk... ", :magenta)}"
        upload_file(vm_disk, "#{destination_path}/#{vm_name}.qcow2") 
        vm.start
        
        puts "#{ui.color("VM Name", :cyan)}: #{vm.name}"
        puts "#{ui.color("VM Memory", :cyan)}: #{vm.memory_size.to_i.kilobytes.to.megabytes.round} MB"

        # wait for it to be ready to do stuff
        print "\n#{ui.color("Waiting server... ", :magenta)}"
        timeout = 100
        found = connection.servers.all.find { |v| v.name == vm.name }
        loop do 
          begin
            if not vm.addresses.nil? and not vm.addresses.empty?
              puts
              puts "\n#{ui.color("VM IP Address: #{vm.public_ip_address}", :cyan)}"
              break
            end
          rescue Fog::Errors::Error
            print "\r#{ui.color('Waiting a valid IP', :magenta)}..." + "." * (100 - timeout)
          end
          timeout -= 1
          if timeout == 0
            ui.error "Timeout trying to reach the VM. Couldn't find the IP address."
            exit 1
          end
          sleep 1
          found = connection.servers.all.find { |v| v.name == vm.name }
        end

        print "\n#{ui.color("Waiting for sshd... ", :magenta)}"
        print(".") until tcp_test_ssh(vm.public_ip_address) { sleep @initial_sleep_delay ||= 10; puts(" done") }
        bootstrap_for_node(vm).run

        puts "\n"
        puts "#{ui.color("Name", :cyan)}: #{vm.name}"
        puts "#{ui.color("IP Address", :cyan)}: #{vm.public_ip_address}"
        puts "#{ui.color("Environment", :cyan)}: #{config[:environment] || '_default'}"
        puts "#{ui.color("Run List", :cyan)}: #{config[:run_list].join(', ')}"
        puts "#{ui.color("Done!", :green)}"
      end

      def bootstrap_for_node(vm)
        bootstrap = Chef::Knife::Bootstrap.new
        bootstrap.name_args = [vm.public_ip_address]
        bootstrap.config[:run_list] = config[:run_list]
        bootstrap.config[:ssh_user] = config[:ssh_user] 
        bootstrap.config[:identity_file] = config[:identity_file]
        bootstrap.config[:chef_node_name] = config[:chef_node_name] || vm.name
        bootstrap.config[:bootstrap_version] = locate_config_value(:bootstrap_version)
        bootstrap.config[:distro] = locate_config_value(:distro)
        # bootstrap will run as root...sudo (by default) also messes up Ohai on CentOS boxes
        bootstrap.config[:use_sudo] = true unless config[:ssh_user] == 'root'
        bootstrap.config[:template_file] = locate_config_value(:template_file)
        bootstrap.config[:environment] = config[:environment]
        bootstrap.config[:no_host_key_verify] = config[:no_host_key_verify]
        bootstrap.config[:ssh_password] = config[:ssh_password]
        bootstrap
      end

    end
  end
end
