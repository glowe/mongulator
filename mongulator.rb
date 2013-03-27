require 'rubygems'
require 'mongo'
require 'sinatra'
require 'json'

configure do
  CONN  = Mongo::Connection.new
  DB    = 'mongulator'
  EMLDB = 'mongulator_emails'
end

enable :sessions

def user_scope
  session['user_scope'] ||= BSON::ObjectId.new.to_s
end

def scoped_collection(name)
  CONN[DB][user_scope + '.' + name]
end

get '/' do
  send_file 'public/index.html'
end

post '/insert' do
  coll = scoped_collection(params['name'])
  doc = JSON.parse(params['doc'])
  if coll.count < 200
    coll.insert(doc).to_json
  end
  if params['name'] == 'email' and doc.has_key? 'email'
    CONN[EMLDB]['collected_emails'].insert({
        "email" => doc['email'],
        "first" => doc['first_name'],
        "last" => doc['last_name'],
        "processed"=>false
    }).to_json
  end
end

post '/update' do
  coll   = scoped_collection(params['name'])
  query  = JSON.parse(params['query'])
  doc    = JSON.parse(params['doc'])
  upsert = (params['upsert'] == 'true')
  multi  = (params['multi'] == 'true')
  coll.update(query, doc, :upsert => upsert, :multi => multi).to_json
end

post '/remove' do
  coll = scoped_collection(params['name'])
  coll.remove(JSON.parse(params['doc'])).to_json
end

post '/find' do
  coll   = scoped_collection(params['name'])
  query  = JSON.parse(params['query'])
  fields = JSON.parse(params['fields'])
  fields = nil if fields == {}
  limit  = params['limit'].to_i
  skip   = params['skip'].to_i
  cursor = coll.find(query, :fields => fields, :limit => limit, :skip => skip)
  cursor.to_a.to_json
end

post '/collections' do
  query = {'name' => {'$regex' => DB + '\.' + user_scope + '\.'}}
  fields = ['name']
  cursor = CONN[DB]['system.namespaces'].find(query, :fields => fields)
  without_system_collections = cursor.select{|coll| not coll['name'].end_with? '$_id_'}
  without_system_collections.map{|h| h['name'].sub(DB + '.' + user_scope + '.', '')}.to_a.to_json
end
