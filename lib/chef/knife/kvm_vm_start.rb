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
    class KvmVmStart < Knife

      include Knife::KVMBase

      banner "knife kvm vm start VM_NAME [VM_NAME] (options)"

      option :force_start,
        :long => "--force-start",
        :boolean => true,
        :default => false,
        :description => "Force VM start"

      def run
        start = []
        connection.servers.all.each do |vm|
          @name_args.each do |vm_name|
            if vm_name == vm.name
              if config[:force_start] and vm.stopped?
                confirm("Do you really want to start this virtual machine '#{vm.name}'")
              end

              if vm.stopped?
                ui.info "#{ui.color(" Starting Virtual machine #{vm.name} ... ", :magenta)}"
                vm.start
              end

              start << vm_name
              ui.warn("starting virtual machine #{vm.name}")
            end
          end
        end
        @name_args.each do |vm_name|
          ui.warn "Virtual Machine #{vm_name} not found, it might not be running still" if not start.include?(vm_name)
        end
      end

    end
  end
end
