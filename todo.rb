require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

require_relative "database_persistence"

configure do
  set :erb, escape_html: true
  enable :sessions
  set :sessions_secret, 'secret'
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistence.new
end

helpers do
  # return true if complete, false if not complete
  def list_status?(item)
    p "I am inside list_status?: #{item}"
    item[:status] == "t"
  end

  def finished?(list)
    list_complete?(list) && !empty?(list)
  end

  def load_list(list_num)
    if list_num && @storage.list_exsits?(list_num)
      list = @storage.find_list(list_num)
    end
    return list if list

    session[:error] = "The specified list was not found."
    redirect "/lists"
  end

  def list_complete?(list_num)
    current_list = @storage.find_list_items(list_num)

    current_list.all? do |item|
      item[:status] == "t"
    end
  end

  def empty?(list_num)
    current_list = @storage.find_list_items(list_num).empty?
  end

  def create_tag(list_num, string)
    if finished?(list_num)
      string.insert(-2, "class=\"complete\"")
    else
      string
    end
  end

  def uncompleted_items(list_num)
    current_list = @storage.find_list_items(list_num)
    current_list.select do |item|
      item[:status] != "complete"
    end.size
  end

  def sort(lists)
    finished, unfinished = lists.partition do |list|
      finished?(list[:id])
    end

    (unfinished + finished).each do |list|
      yield(list)
    end
  end

  def sort_items(items)
    finished, unfinished = items.partition do |item|
      item[:status] == "complete"
    end

    (unfinished + finished).each do |item|
      yield(item)
    end
  end
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = @storage.to_a

  erb :lists
end

get "/lists/add" do
  erb :add
end

get "/lists/:number" do |num|
  load_list(num.to_i)
  @name = @storage.find_list_name(num)
  @num = num.to_i
  p @current_list_items = @storage.find_list_items(num)

  erb :list
end

# Return an error message if the name is invalid. Return nil if it is valid
def error_for(list_name)
  if @storage.unique_list_name?(list_name)
    "Pick a unique list name."
  elsif !((1..100).cover? list_name.size)
    "The list name must be between 1 and 100 characters."
  end
end

post "/lists" do
  list_name = params[:list_name].strip

  error = error_for(list_name)
  if error
    session[:error] = error
    erb :add
  else
    @storage.add_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:number/change_name" do |num|
  load_list(num.to_i)
  @num = num
  @current_list = @storage.find_list_name(num)
  erb :rename
end

post "/lists/:number/change_name" do |num|
  load_list(num.to_i)
  list_name = params[:list_name].strip
  @num = num

  error = error_for(list_name)
  if error
    session[:error] = error
    erb :rename
  else
    @storage.set_list_name(num, list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{num}"
  end
end

post "/lists/:number/delete" do |num|
  load_list(num.to_i)
  @storage.delete_list(num)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect("/lists")
  end
end

post "/lists/:number/add_todo" do |num|
  load_list(num.to_i)
  @storage.add_todo(num, params[:todo])

  redirect("/lists/#{num}")
end

post "/lists/:number/remove_todo/:element" do |num, ele|
  load_list(num.to_i)
  @storage.delete_todo(num, ele)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204 # Successful status code
  else
    session[:success] = "The todo has been deleted."
    redirect("/lists/#{num}")
  end
end

post "/lists/:number/list/:element/complete" do |num, ele|
  load_list(num.to_i)
  p "What is completed? #{params["completed"]}"
  @storage.set_todo_status(num, ele, params["completed"])

  redirect("/lists/#{num}")
end

post "/lists/:number/list/complete_all" do |num|
  load_list(num.to_i)
  @storage.complete_all_todos(num)

  session[:success] = "All the todo's have been completed!"

  redirect("/lists/#{num}")
end
