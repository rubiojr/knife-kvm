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
    class KvmVmList < Knife

      include Knife::KVMBase

      banner "knife kvm vm list (options)"

      def run
        $stdout.sync = true
        vm_table = table do |t|
          t.headings = %w{NAME STATE MAX_MEM CPUS OS_TYPE ARCH}
          connection.servers.each do |vm|
            t << [vm.name, vm.state, "#{vm.memory_size/1024} MB", vm.cpus, vm.os_type, vm.arch]
          end
        end
        puts vm_table
      end
    end
  end
end
