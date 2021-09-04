require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  set :erb, escape_html: true
  enable :sessions
  set :sessions_secret, 'secret'
end

def load_list(list_num)
  if list_num && session[:lists].find { |list| list[:id] == list_num.to_i }
    list = session[:lists].select { |list| list[:id] == list_num.to_i }[0]
  end
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

before do
  session[:lists] ||= []
end

helpers do
  # return true if complete, false if not complete
  def list_status?(item)
    !!(item[:status])
  end

  def finished?(list)
    list_complete?(list) && !empty?(list)
  end

  def list_complete?(list_num)
    current_list = session[:lists].select { |list| list[:id] == list_num.to_i }[0][:items]
    # I need to look within the current_list array for the list with an :id equal to list_num
    # [list_num.to_i][:items]

    current_list.all? do |item|
      item[:status] == "complete"
    end
  end

  def empty?(list_num)
    current_list = session[:lists].select { |list| list[:id] == list_num.to_i }[0][:items].empty?
    # session[:lists][list.to_i][:items].empty?
  end

  def create_tag(list_num, string)
    if finished?(list_num)
      string.insert(-2, "class=\"complete\"")
    else
      string
    end
  end

  def uncompleted_items(list_num)
    current_list = session[:lists].select { |list| list[:id] == list_num.to_i }[0][:items]
    current_list.select do |item|
      item[:status] != "complete"
    end.size
  end

  def sort(lists)
    # lists.each_with_index do |list, index|
    #   list[:index] = index
    # end

    finished, unfinished = lists.partition do |list|
      finished?(list[:id])
    end

    (unfinished + finished).each do |list|
      # yield(list, list[:index])
      yield(list)
    end
  end

  def sort_items(items)
    # items.each.with_index do |item, index|
    #   item[:index] = index
    # end

    finished, unfinished = items.partition do |item|
      item[:status] == "complete"
    end

    (unfinished + finished).each do |item|
      # yield(item, item[:index])
      yield(item)
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

  current_list = session[:lists].select { |list| list[:id] == num.to_i }[0]

  @name = current_list[:name]
  @num = current_list[:id]
  @current_list_items = current_list[:items]

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

def next_id(array)
  max = array.map { |item| item[:id] }.max || -1
  max + 1
end

post "/lists" do
  list_name = params[:list_name].strip

  error = error_for(list_name)
  if error
    session[:error] = error
    erb :add
  else
    id = next_id(session[:lists])
    session[:lists] << { id: id, name: list_name, items: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:number/change_name" do |num|
  load_list(num.to_i)
  @num = num
  @current_list = session[:lists].select { |list| list[:id] == num.to_i }[0][:name]
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
    session[:lists].select { |list| list[:id] == num.to_i }[0][:name] = params[:list_name]
    session[:success] = "The list has been updated."
    redirect "/lists/#{num}"
  end
end

post "/lists/:number/delete" do |num|
  load_list(num.to_i)
  session[:lists].reject! { |list| list[:id] == num.to_i}
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect("/lists")
  end
end

post "/lists/:number/add_todo" do |num|
  load_list(num.to_i)

  current_list = session[:lists].select { |list| list[:id] == num.to_i }[0][:items]
  id = next_id(current_list)
  current_list << { id: id, name: params[:todo] }
  redirect("/lists/#{num}")
end

post "/lists/:number/remove_todo/:element" do |num, ele|
  load_list(num.to_i)
  session[:lists].select { |list| list[:id] == num.to_i }[0][:items].reject! { |item| item[:id] == ele.to_i }
  # session[:lists][num.to_i][:items].delete_at(ele.to_i)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204 # Successful status code
  else
    session[:success] = "The todo has been deleted."
    redirect("/lists/#{num}")
  end
end

post "/lists/:number/list/:element/complete" do |num, ele|
  load_list(num.to_i)

  items = session[:lists].select { |list| list[:id] == num.to_i }[0][:items]
  todo = items.select { |todo| todo[:id] == ele.to_i}

  items.each.with_index do |item, index|
    if ele.to_i == item[:id]
      if list_status?(todo[0])
        session[:lists][num.to_i][:items][index][:status] = nil
      else
        session[:lists][num.to_i][:items][index][:status] = "complete"
      end
    end
  end



  redirect("/lists/#{num}")
end

post "/lists/:number/list/complete_all" do |num|
  load_list(num.to_i)

  session[:lists].select { |list| list[:id] == num.to_i }[0][:items].each do |item|
    item[:status] = "complete"
  end

  session[:success] = "All the todo's have been completed!"

  redirect("/lists/#{num}")
end

# Update the 2/4 items left to do thing
