
$script = <<SCRIPT
  apt-get update
  apt-get install -y postgresql-14 postgresql-server-dev-14 make gcc
  sudo -u postgres createdb foo
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.network :forwarded_port, guest: 5432, host: 65432
  config.vm.provision "shell", inline: $script
end

