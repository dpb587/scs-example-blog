Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-raring-server-amd64'
  config.vm.box_url = 'http://cloud-images.ubuntu.com/vagrant/raring/20140125/raring-server-cloudimg-amd64-vagrant-disk1.box'

  config.vm.network :private_network, ip: '192.168.191.92'

  config.vm.provider :virtualbox do |v|
    v.customize [ 'modifyvm', :id, '--memory', '1536' ]
    v.customize [ 'modifyvm', :id, '--nictype2', 'Am79C973' ]
    v.customize [ 'modifyvm', :id, '--nicpromisc2', 'allow-all' ]
  end

  config.vm.provision :shell, :inline => 'cd /vagrant && ./provision.sh'
end
