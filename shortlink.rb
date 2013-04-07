require "sinatra"
require "sinatra/sequel"
require "json"

set :database, "sqlite://shortlinks.db"

migration "Create 'tokens' table" do
  database.create_table :tokens do
    primary_key :id
    column :token, String, null: false
    column :url, String, text: true, null: false

    unique :token
    index :url
  end
end

get "/:token" do
  record = database[:tokens].first!("token = ?", params[:token])
  redirect record[:url]
end

get "/:token/info" do
  record = database[:tokens].first!("token = ?", params[:token])
  content_type :json
  return JSON.dump({
    token: record[:token],
    shortlink: url("/#{record[:token]}"),
    url: record[:url]
  })
end

post "/" do
  url = URI(params[:url]).normalize.to_s
  token = nil
  database.transaction do
    while token.nil? || database[:tokens].first("token = ?", token)
      token = rand(36 ** 4).to_s(36).rjust(4, "0")
    end
    database[:tokens].insert(token: token, url: url)
  end
  redirect to("/#{token}/info")
end
