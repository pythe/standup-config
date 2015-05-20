require 'sinatra'
require 'net/https'
require 'json'

def tracker_domain
  ENV.fetch('TRACKER_ENV', 'www') + ".pivotaltracker.com"
end

def me_url
  URI("https://#{tracker_domain}/services/v5/me")
end

def projects_url
  URI("https://#{tracker_domain}/services/v5/projects")
end

def get(uri, basic_auth: nil, headers: {})
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Get.new(uri)
  headers.each do |header, value|
    req[header] = value
  end
  req.basic_auth basic_auth[:user], basic_auth[:password] if basic_auth
  response = http.request(req)
  return response
end

class StandupConfig < Sinatra::Base
  enable :sessions

  get '/login' do
    session["return"] = params["return_to"]
    if params["api_token"]
      session["api_token"] = params["api_token"]
      redirect to("/config")
    else
      File.read("templates/login.html")
    end
  end

  post '/login' do
    response = get(me_url, basic_auth: {user: params["username"], password: params["password"]})
    user_data = JSON.parse(response.body)
    session["api_token"] = user_data.fetch("api_token")
    redirect to("/config")
  end

  get '/config' do
    erb "templates/config.html.erb"
  end

  post '/config' do
    give_pebble_value(params)
  end

  get '/logout' do
    give_pebble_value(clear: "yes")
  end

  private

  def give_pebble_value(value)
    data = JSON.dump(value)
    redirect "#{pebble_config_redirect_location}#{URI.encode(data)}", "good job, you configured it"
  end

  def pebble_config_redirect_location
    session.delete("return") || "pebblejs://close#"
  end

  def api_token
    session["api_token"]
  end

  def initials
    user_data.fetch('initials')
  end

  def projects
    @projects ||= user_data.fetch("projects").map { |membership|
      {
        id: membership["project_id"],
        name: membership["project_name"]
      }
    }
  end

  def user_data
    @user_data ||= get_user_data
  end

  def get_user_data
    response = get(me_url, headers: {"X-TrackerToken" => api_token})
    user_data = JSON.parse(response.body)
  end

  def erb(template_path)
    ERB.new(File.read(template_path)).result(binding)
  end
end
