require 'sinatra'
require_relative 'containers'

# Get the current status of all the containers
get '/status' do
  content_type :json
  running_state.to_json
end

# Relaunch all the users in the system and returns a report
get '/relaunch' do
  relaunch_users
  content_type :json
  running_state.to_json
end

# launch only a certain user and returns the port its editor is running
# params: username
get '/launch' do
  begin
    username = params["username"]
    if username.nil? || username.empty?
       "You need to provide your username and password for this call"
    else
      launch_redirect_container(username)
    end
  rescue ContainerNotFound => e
    "Container for user #{username} not found. Register it first"
  end
end

# Registers a new user and launch his container
# post params : username and password
post '/register' do
  begin
    json_object = JSON.parse(request.body.read)
  rescue JSON::ParserError
    return_json(400, {"Error" => "Unable to parse input"})
  end

  username = json_object.delete("username")
  password = json_object.delete("password")

  if username.nil? || username.empty?
    return_json(422, {"Error" => "Invalid Request Body: The username is missing"})
  end

  if password.nil? || password.empty?
    return_json(422, {"Error" => "Invalid Request Body: The username is missing"})
  end

  response = create_container(username, password)
  headers = {"Content-Type" => 'application/json'}

  [201, headers, response.to_json]

end

#Almost useless Sanity check
get '/app_status' do
  "The Destrakun application is up and running"
end
