require 'json'
require 'yaml'

IMAGE="railsmania/codebox"
RAILS_PORT = 3000;
EDITOR_PORT = 8000;
USERS_FILE = "all_users.yml"
CONTAINER_PREFIX = "user_"

class ContainerNotFound < StandardError
end

def launch_redirect(username)
  container_namae = container_name(username)
  if !exists_container?(container_namae)
    raise ContainerNotFound
  end
  if !running?(container_namae)
    launch_container(container_name)
    sleep(0.1)
  end

  editor_port = get_ports(container_namae)[:editor_port]
  "http://128.199.229.42:#{editor_port}"
end


def register_container(username, password)
  container_namae = container_name(username)
  if !exists_container?(container_namae)
    create_container(username, password)
    20.times do |counter|
      sleep(0.1)
      break if exists_container?(container_namae)
      if counter > 15
         raise "The container for #{username} could not be launched or system too slow"
      end
    end
  end

  ports = get_ports(container_namae)
  container_info = {container: container_namae, username: username, password: password}.merge(ports)
  container_info
end

# NOT needed We store local information so we can recre
def update_container_info(username, container_info)
  all_users = YAML.load(File.open(USERS_FILE)) || {}
  all_users[username] = container_info
  File.open(USERS_FILE, 'w') {|f| f.write all_users.to_yaml }
end

def relaunch_users
  all_user_containers.each do |user_container_name|
    if !running?(user_container_name)
      launch_container(user_container_name)
    end
  end
end

def launch_container(container_name)
  fork do
    exec("docker start #{user_container_name}")
  end
end

def running_state
  all_user_containers.map do |user_container_name|
    {user_container_name => running?(user_container_name)}.merge(get_ports(user_container_name))
  end
end

def running?(container_name)
    data = container_data(container_name)
    data["State"]["Running"]
end


def all_user_containers
  all_containers = `docker ps -a`
  user_containers = all_containers.split("\n").select{|container| container.include? CONTAINER_PREFIX}
  user_containers.map{|container| container.split(" ").last}
end

def container_name(username)
  "#{CONTAINER_PREFIX}#{username}" #user_testuser
end

def create_container(username, password)
  credentials = "#{username}:#{password}"
  name = container_name(username)

  command = "docker run -d -p 0:8000 -p 0:3000 --name #{name} #{IMAGE} codebox run /workspace -u #{credentials}"

  fork do
    exec(command)
  end
end


def exists_container?(container_name)
  !container_data(container_name).nil?
end

def get_ports(container_name)
  data = container_data(container_name)
  return {} unless data
  ports_data= data["NetworkSettings"]["Ports"]
  return {} unless ports_data
  host_rails_port = ports_data["#{RAILS_PORT}/tcp"].first["HostPort"]
  host_editor_port = ports_data["#{EDITOR_PORT}/tcp"].first["HostPort"]
  {rails_port: host_rails_port, editor_port: host_editor_port}
end

def container_data(container_name)
  output = `docker inspect #{container_name}`
  JSON.parse(output).first
end
