# 0.2 - UNRELEASED

* Added --batch and --async options 

In batch mode a YAML file describes the VMs you want to bootstrap.
    
    knife kvm vm create --batch batch.yml 

Sample batch.yml file:

    ---
    :testvm1:
      'kvm-host': blackops
      'vm-memory': 1024
      'vm-disk': /home/rubiojr/tmp/ubuntu-precise-with-ip-info.qcow2
      'extra-args': --no-host-key-verify --skip-bootstrap
    
    :testvm2:
      'kvm-host': blackops
      'vm-disk': /home/rubiojr/tmp/ubuntu-precise-with-ip-info.qcow2
      'extra-args': --no-host-key-verify 
    
    :testvm3:
      'kvm-host': blackops
      'vm-memory': 512 
      'vm-disk': /home/rubiojr/tmp/ubuntu-precise-with-ip-info.qcow2
      'extra-args': --no-host-key-verify


This will try to create three VMs (testvm1, testvm2 and testvm3) sequentially. VM definitions inside the batch file accept all the parameters that can be used with knife-kvm.

If you want to bootstrap the VMs asynchronously, use the --async flag.

    knife kvm vm create --batch batch.yml --async

* Added --skip-bootstrap flag. If the flag is used the VM will be created but 
  the bootstrap template/script won't be executed (it also means that Chef won't be installed).

IMPORTANT: --async mode needs SSH pubkey auth at the moment, password authentication won't work.
