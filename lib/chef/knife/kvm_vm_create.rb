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
require 'open4'
require 'celluloid'
require 'singleton'

class Chef
	class Knife
		class DeployScript

			attr_reader :job_count

			# Sample job
			#---
			#:test1:
			#  'vm-memory':
			#  'extra-args':
			#  'kvm-host':
			#  'template-file':
			#  'vm-disk':
			#  'ssh-user':
			#  'ssh-password':
			#  'run-list':
			#  'network-interface':
			def initialize(batch_file)
				@batch_file = batch_file
				@jobs = []
				@job_count = 0
				(YAML.load_file batch_file).each do |i|
					@jobs << DeployJob.new(i)
					@job_count += 1
				end
			end

			def each_job(&block)
				@jobs.each do |j|
					yield j
				end
			end

		end

		class CLogger
			include Celluloid
			include Singleton

			def info(msg)
				puts "INFO: #{msg}"
			end

			def error(msg)
				$stderr.puts "ERROR: #{msg}"
			end
		end

		class DeployJob

			include Celluloid

			attr_reader :name

			def initialize(options)
				@name, @options = options
				validate
			end

			def validate
				if @name.nil? or @name.empty?
					raise Exception.new("Invalid job name")
				end
				if not @options['vm-disk'] or !File.exist?(@options['vm-disk'])
					raise Exception.new("Invalid VM disk for job #{@name}.")
				end
			end

			# returns [status, stdout, stderr]
			def run
				args = ""
				extra_args = ""
				@options.each do |k, v|
					if k == 'extra-args'
						extra_args << v
					else
						args << "--#{k} #{v} " unless k == 'extra-args'
					end
				end

				#puts "DEBUG: knife kvm vm create #{args} #{extra_args}"
				@out = ""
				@err = ""
				optstring = []
				@options.each do |k,v|
					optstring << "   - #{k}:".ljust(25) +  "#{v}\n"
				end
				CLogger.instance.info! "Bootstrapping VM #{@name} \n#{optstring.join}"
				@status = Open4.popen4("knife kvm vm create --vm-name #{@name} #{args} #{extra_args}") do |pid, stdin, stdout, stderr|
					@out << stdout.read.strip
					@err << stderr.read.strip
				end
				if @status == 0
					CLogger.instance.info! "[#{@name}] deployment finished OK"
				else
					CLogger.instance.error! "[#{@name}] deployment FAILED"
					@err.each_line do |l|
						CLogger.instance.error! "[#{@name}] #{l.chomp}"
					end
				end
				return @status, @out, @err
			end

		end

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

			option :vm_disk_max_size,
				:long => "--vm-disk-max-size SIZE",
				:default => '10G',
				:description => "Maximum disk size in GB, default: 10G"

			option :vm_disk_alloc_size,
				:long => "--vm-disk-alloc-size SIZE",
				:default => '5G', #"#{File.size(vm_disk)/1024/1024}M",
				:description => "Preallocated disk size in GB, default: 5G"

			option :vm_disk_format,
				:long => "--vm-disk-format FORMAT",
				:default => "qcow2",
				:description => "Disk image format type"

			option :vm_disk_create,
				:long => "--vm-disk-create",
				:description => "Don't copy lcoal disk image, create new one.",
				:boolean => true,
				:default => false

			option :vm_name,
				:long => "--vm-name NAME",
				:description => "The Virtual Machine name"

			option :vm_arch,
				:long => "--vm-arch ARCH",
				:default => "x86_64",
				:description => "The Virtual Machine architecture x86_64/i686"

			option :vm_autostart,
				:long => "--vm-autostart",
				:description => "Automatically start vm after host shutdown.",
				:boolean => true,
				:default => false

			option :vm_iso_dir,
				:long => "--vm-iso-dir DIR",
				:default => "/data/machines/iso",
				:description => "Base directory for ISO images /data/machines/iso"

			option :vm_iso_file,
				:long => "--vm-iso-file FILENAME",
				:description => "ISO Image file name, path to file is made from base_directory/filename"

			option :vm_iso_url,
				:long => "--vm-iso-url URL",
				:description => "Is an URL from which ISO file will be downloaded to base_directory/filename"

			option :cpus,
				:long => "--vm-cpus CPUS",
				:default => "1",
				:description => "Number of VM cpus in VM"

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

			option :max_memory,
				:long => "--vm-max-memory MEM",
				:default => "512",
				:description => "The maximum VM memory allocation in MB (default: 512)"

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

			option :skip_bootstrap,
				:long => "--skip-bootstrap",
				:description => "Skip bootstrap process (Deploy only mode)",
				:boolean => true,
				:default => false,
				:proc => Proc.new { true }

			option :async,
				:long => "--async",
				:description => "Deploy the VMs asynchronously (Ignored unless combined with --batch)",
				:boolean => true,
				:default => false,
				:proc => Proc.new { true }

			option :network_interface,
				:long => "--network-interface type:name",
				:description => "The network interface description (default bridge:br0)",
				:default => "bridge:br0"

			option :batch,
				:long => "--batch script.yml",
				:description => "Use a batch file to deploy multiple VMs",
				:default => nil

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

				if config[:batch]
					CLogger.instance.info "Running in batch mode. Extra arguments will be ignored."
					if not config[:async]
						counter = 0
						script = DeployScript.new(config[:batch])
						script.each_job do |job|
							counter += 1
							status, stdout, stderr = job.run
							if status == 0
								puts 'Ok'
							else
								puts 'Failed'
								stderr.each_line do |l|
									ui.error l
								end
							end
						end
					else
						CLogger.instance.info! "Asynchronous boostrapping selected"
						CLogger.instance.info! "Now do something productive while I finish my job ;)"
						script = DeployScript.new(config[:batch])
						futures = []
						script.each_job do |job|
							futures << job.future(:run)
						end
						futures.each do |f|
							f.value
						end
					end
					return
				end

				unless config[:vm_disk]
					ui.error("You have not provided a valid QCOW2 file. (--vm-disk)")
					exit 1
				end

				if not File.exist?(config[:vm_disk]) and config[:vm_disk_create].nil?
					ui.error("Invalid QCOW2 disk file (--vm-disk)")
					exit 1
				end

				vm_name = config[:vm_name]
				if not vm_name
					ui.error("Invalid Virtual Machine name (--vm-name)")
					exit 1
				end

				pool = config[:pool]
				vm_memory = config[:memory].to_i * 1024
				vm_max_memory = config[:max_memory].nil? ? vm_memory : (config[:max_memory].to_i * 1024)
				vm_arch = config[:vm_arch]
				vm_cpus = config[:vm_cpus]
				vm_disk = config[:vm_disk]
				vm_disk_format = config[:vm_disk_format].nil? ? 'qcow2' : config[:vm_disk_format]
				vm_disk_max_size = config[:vm_disk_max_size]
				vm_disk_alloc_size = config[:vm_disk_alloc_size]
				os_type =config[:os_type]
				autostart = config[:vm_autostart]
				destination_path = "/var/lib/libvirt/images/"
				iso_dir = config[:vm_iso_dir]
				iso_file = config[:vm_iso_file]

				if config[:vm_disk_create].nil?
					puts "#{ui.color("Importing VM disk... ", :magenta)}"
					upload_file(vm_disk, "#{destination_path}/#{vm_name}.qcow2")
				end


				if not config[:vm_iso_url].nil?
					puts "#{ui.color("Downloading iso File from URL: #{config[:vm_iso_url]} to #{iso_dir}/#{iso_file} ... ", :magenta)}"
					download_file(config[:vm_iso_url], "#{iso_dir}/#{iso_file}")
				end

				#connection.remote_command "mkdir #{destination_path}"
				puts "#{ui.color("Creating VM... ", :magenta)}"
				net_type, net_if = config[:network_interface].split(':')
				vm = connection.servers.create :name => vm_name,
													:arch => vm_arch,
													:cpus => vm_cpus,
													:volume_allocation => vm_disk_alloc_size,
													:volume_capacity => vm_disk_max_size,
													:volume_format_type => vm_disk_format,
													:autostart => autostart, # Starting guest automatically
													:volume_pool_name => pool,
													:network_interface_type => net_type,
													:memory_size => vm_memory,
													:max_memory_size => vm_max_memory,
													:network_bridge_name => net_if,
													:iso_dir => iso_dir,
													:iso_file => iso_file

				if config[:autostart]
					puts "#{ui.color("Making VM autostart", :magenta)}"
					make_vm_autostart(vm_name)
				end

				vm.start

				puts "#{ui.color("VM Name", :cyan)}: #{vm.name}"
				puts "#{ui.color("VM Memory", :cyan)}: #{vm.memory_size/1024} MB"

				return if config[:skip_bootstrap]

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
