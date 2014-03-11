#
# Author:: Sergio Rubio (<rubiojr@frameos.org>)
# Copyright:: Copyright (c) 2011 Sergio Rubio
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
    class KvmVmDelete < Knife

      include Knife::KVMBase

      banner "knife kvm vm delete VM_NAME [VM_NAME] (options)"

      option :force_delete,
        :long => "--force-delete",
        :boolean => true,
        :default => false,
        :description => "Do not confirm VM deletion when yes"

      option :shutdown_first,
        :long => "--shutdown-first",
        :default => false,
        :description => "Try to shutdown machine first if it's running."

      option :shutdown_timeout,
        :long => "--shutdown-timeout",
        :default => 60,
        :description => "Wait timeout for shutdown to wait for vm"

      def run
        deleted = []
        connection.servers.all.each do |vm|
          @name_args.each do |vm_name|
            if vm_name == vm.name
              if config[:force_delete]
                confirm("Do you really want to delete this virtual machine '#{vm.name}'")
              end

              unmake_vm_autostart(vm.name)

              if config[:shutdown_first] and vm.active?
                ui.info "#{ui.color(" Shuting down Virtual machine #{vm.name} before deletion ... ", :magenta)}"
                vm.shutdown
                time=0
                #
                # Wait for VM shutdown
                #
                while vm.active?
                  break if time == config[:shutdown_timeout]
                  time += 1
                  sleep 1
                end
              end

              vm.destroy(options = { :destroy_volumes => true })
              deleted << vm_name
              ui.warn("Deleted virtual machine #{vm.name}")
            end
          end
        end
        @name_args.each do |vm_name|
          ui.warn "Virtual Machine #{vm_name} not found" if not deleted.include?(vm_name)
        end
      end

    end
  end
end
