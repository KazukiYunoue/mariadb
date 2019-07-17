#
# Cookbook:: mariadb
# Recipe:: default
#
# Copyright:: 2019, The Authors, All Rights Reserved.

yum_repository "MariaDB" do
  baseurl "http://yum.mariadb.org/10.3/centos7-amd64"
  gpgkey "https://yum.mariadb.org/RPM-GPG-KEY-MariaDB"
  gpgcheck true
end

["MariaDB-server", "MariaDB-client", "MariaDB-backup", "galera", "socat"].each do |pkg|
  package pkg do
    action :install
  end
end

service "mariadb" do
  action [:enable, :start]
  supports :status => true, :restart => true
end

execute "galera_new_cluster" do
	command "galera_new_cluster"
	action :nothing
end

execute "set root password" do
  command "mysqladmin password #{node["mariadb"]["root_password"]}"
  not_if "mysql -uroot -p#{node["mariadb"]["root_password"]} -e 'show databases;'"
end

execute "sstuser" do
  command "mysql -uroot -p#{node["mariadb"]["root_password"]} -e \"CREATE USER 'sstuser'@'localhost' IDENTIFIED BY '#{node["mariadb"]["sstuser_password"]}'; GRANT RELOAD, LOCK TABLES, PROCESS, REPLICATION CLIENT ON *.* TO 'sstuser'@'localhost';\""
  not_if "mysql -uroot -p#{node["mariadb"]["root_password"]} -e \"SHOW GRANTS FOR 'sstuser'@'localhost'\";"
end

template "/etc/my.cnf.d/server.cnf" do
  source "server.cnf.erb"
  user "root"
  group "root"
  mode 0644
  case node["mariadb"]["bootstrap?"]
  when true then
    notifies :stop, "service[mariadb]", :immediately
    notifies :run, "execute[galera_new_cluster]", :immediately
  else
    notifies :restart, "service[mariadb]", :immediately
  end
end
