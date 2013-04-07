require "sinatra"
require "sinatra/sequel"
require "json"

set :database, "sqlite://shortlinks.db"
set :token_length, 3

migration "Create 'tokens' table" do
  database.create_table :tokens do
    primary_key :id
    column :token, String, null: false
    column :url, String, text: true, null: false

    unique :token
    index :url
  end
end

migration "Create 'hits' table" do
  database.create_table :hits do
    primary_key :id
    foreign_key :token_id, :tokens, null: false
    column :access_time, DateTime, null: false
    column :user_agent, String, text: true
    column :user_ip, String
    column :referer, String, text: true

    index [:token_id, :user_agent]
    index [:token_id, :referer]
  end
end

get "/:token" do
  record = database[:tokens].first!("token = ?", params[:token])
  database[:hits].insert({
    token_id: record[:id],
    access_time: Time.now,
    user_agent: request.user_agent,
    user_ip: request.ip,
    referer: request.referer
  })
  redirect record[:url]
end

get "/:token/info" do
  record = database[:tokens].first!("token = ?", params[:token])
  content_type :json
  return JSON.dump({
    token: record[:token],
    shortlink: url("/#{record[:token]}"),
    url: record[:url],
    hit_count: database[:hits].where("token_id = ?", record[:id]).count
  })
end

post "/" do
  url = URI(params[:url]).normalize.to_s
  token = nil
  database.transaction do
    while token.nil? || database[:tokens].first("token = ?", token)
      token = rand(36 ** settings.token_length).to_s(36).rjust(settings.token_length, "0")
    end
    database[:tokens].insert(token: token, url: url)
  end
  redirect to("/#{token}/info")
end
