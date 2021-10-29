class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def to_a
    @session[:lists]
  end

  def find_list_items(list_num)
    find_list(list_num)[:items]
  end

  def find_list_name(list_num)
    find_list(list_num)[:name]
  end

  def set_list_name(list_num, name)
    find_list(list_num)[:name] = name
  end

  def find_list(list_num)
    @session[:lists].select { |list| list[:id] == list_num.to_i }[0]
  end

  def add_list(list_name)
    id = next_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, items: [] }
  end

  def unique_list_name?(list_name)
    @session[:lists].any? { |hash| hash[:name] == list_name }
  end

  def delete_list(list_num)
    @session[:lists].reject! { |list| list[:id] == list_num.to_i}
  end

  def add_todo(list_num, todo)
    current_list = find_list_items(list_num)
    id = next_id(current_list)
    current_list << { id: id, name: todo }
  end

  def delete_todo(list_num, todo_num)
    find_list_items(list_num).reject! { |item| item[:id] == todo_num.to_i }
  end

  def find_todo(list_num, todo_num)
    find_list_items(list_num).select { |todo| todo[:id] == todo_num.to_i}[0]
  end

  def set_todo_status(list_num, todo_num)
    todo = find_todo(list_num, todo_num)

    if todo[:status]
      todo[:status] = nil
    else
      todo[:status] = "complete"
    end
  end

  def complete_all_todos(list_num)
    find_list_items(list_num).each do |item|
      item[:status] = "complete"
    end
  end

  def list_exsits?(list_num)
    @session[:lists].find { |list| list[:id] == list_num.to_i }
  end

  private

  def next_id(array)
    max = array.map { |item| item[:id] }.max || -1
    max + 1
  end
end