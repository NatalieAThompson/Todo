require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"


configure do
  set :erb, :escape_html => true
  enable :sessions
  set :sessions_secret, 'secret'
end

def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

before do
  session[:lists] ||= []
end

helpers do
  # return true if complete, false if not complete
  def list_status?(list, item)
    !!(session[:lists][list.to_i][:items][item.to_i][:status])
  end

  def finished?(list)
    list_complete?(list) && !empty?(list)
  end

  def list_complete?(list)
    session[:lists][list.to_i][:items].all? do |item|
      item[:status] == "complete"
    end
  end

  def empty?(list)
    session[:lists][list.to_i][:items].empty?
  end

  def create_tag(list, string)
    if finished?(list)
      string.insert(-2, "class=\"complete\"")
    else
      string
    end
  end

  def uncompleted_items(list)
    session[:lists][list.to_i][:items].select do |item|
      item[:status] != "complete"
    end.size
  end

  def sort(lists)
    lists.each_with_index do |list, index|
      list[:index] = index
    end

    finished, unfinished = lists.partition do |list|
      finished?(list[:index])
    end

    (unfinished + finished).each do |list|
      yield(list, list[:index])
    end
  end

  def sort_items(items)
    items.each.with_index do |item, index|
      item[:index] = index
    end

    finished, unfinished = items.partition do |item|
      item[:status] == "complete"
    end

    (unfinished + finished).each do |item|
      yield(item, item[:index])
    end
  end
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = session[:lists]

  erb :lists
end

get "/lists/add" do
  erb :add
end

get "/lists/:number" do |num|
  load_list(num.to_i)

  @name = session[:lists][num.to_i][:name]
  @num = num
  @current_list_items = session[:lists][num.to_i][:items]

  erb :list
end

# Return an error message if the name is invalid. Return nil if it is valid
def error_for(list_name)
  if session[:lists].any? { |hash| hash[:name] == list_name }
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
    session[:lists] << {name: list_name, items: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:number/change_name" do |num|
  load_list(num.to_i)
  @num = num
  @current_list = session[:lists][0][:name]
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
    session[:lists][num.to_i][:name] = params[:list_name]
    session[:success] = "The list has been updated."
    redirect "/lists/#{num}"
  end
end

post "/lists/:number/delete" do |num|
  load_list(num.to_i)
  session[:lists].delete_at(num.to_i)
  session[:success] = "The list has been deleted."
  redirect("/lists")
end

post "/lists/:number/add_todo" do |num|
  load_list(num.to_i)
  session[:lists][num.to_i][:items] << {name: params[:todo]}
  redirect("/lists/#{num}")
end

post "/lists/:number/remove_todo/:element" do |num, ele|
  load_list(num.to_i)
  session[:lists][num.to_i][:items].delete_at(ele.to_i)
  session[:success] = "The todo has been deleted."
  redirect("/lists/#{num}")
end

post "/lists/:number/list/:element/complete" do |num, ele|
  load_list(num.to_i)
  if list_status?(num.to_i, ele.to_i)
    session[:lists][num.to_i][:items][ele.to_i][:status] = nil
  else
    session[:lists][num.to_i][:items][ele.to_i][:status] = "complete"
  end

  redirect("/lists/#{num}")
end

post "/lists/:number/list/complete_all" do |num|
  load_list(num.to_i)
  session[:lists][num.to_i][:items].each do |item|
    item[:status] = "complete"
  end

  session[:success] = "All the todo's have been completed!"

  redirect("/lists/#{num}")
end

#Update the 2/4 items left to do thing
