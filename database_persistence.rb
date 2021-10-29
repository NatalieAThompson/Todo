require "pg"

class DatabasePersistence
  def initialize
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "ls185")
          end
  end

  def disconnect
    @db.close
  end

  def query(sql, *params)
    puts "#{sql}: #{params}"
    @db.exec_params(sql, params)
  end

  def format(result)
    result.map do |tuple|
      { id: tuple["id"], name: tuple["name"], items: select_all_todos(tuple["id"]) }
    end
  end

  def format_todos(result)
    result.map do |tuple|
      { id: tuple["id"], name: tuple["name"], status: tuple["is_complete"] }
    end
  end

  def select_all_todos(list_num)
    sql = "SELECT * FROM todo WHERE list_id = $1"
    format_todos(query(sql, list_num))
  end

  def to_a
    sql = "SELECT * FROM list;"
    result = query(sql)

    format(result)
  end

  def find_list(list_num)
    sql = "SELECT * FROM list WHERE id = $1;"
    result = query(sql, list_num)

    format(result)[0]
  end

  def find_list_items(list_num)
    find_list(list_num)[:items]
  end

  def find_list_name(list_num)
    find_list(list_num)[:name]
  end

  def set_list_name(list_num, name)
    sql = "UPDATE list SET name = $1 WHERE id = $2;"
    query(sql, name, list_num)
  end

  def add_list(list_name)
    sql = "INSERT INTO list (name) VALUES ($1);"
    query(sql, list_name)
  end

  def unique_list_name?(list_name)
    sql = "SELECT * FROM list WHERE name = $1;"
    !(format(query(sql, list_name)).empty?)
  end

  def delete_list(list_num)
    sql = "DELETE FROM list WHERE id = $1;"
    query(sql, list_num)
  end

  def add_todo(list_num, todo)
    sql = "INSERT INTO todo (name, list_id) VALUES ($1, $2);"
    query(sql, todo, list_num)
  end

  def delete_todo(list_num, todo_num)
    sql = "DELETE FROM todo WHERE list_id = $1 and id = $2;"
    query(sql, list_num, todo_num)
  end

  def find_todo(list_num, todo_num)
    sql = "SELECT * FROM todo WHERE list_id = $1 and id = $2;"
    format_todos(query(sql, list_num, todo_num))[0]
  end

  def set_todo_status(list_num, todo_num, status)
    sql = "UPDATE todo SET is_complete = $1 WHERE list_id = $2 and id = $3;"
    status = status == "true"
    query(sql, !(status), list_num, todo_num)
  end

  def complete_all_todos(list_num)
    sql = "UPDATE todo SET is_complete = true WHERE list_id = $1;"
    query(sql, list_num)
  end

  def list_exsits?(list_num)
    sql = "SELECT * FROM list WHERE id = $1"
    !(format(query(sql, list_num)).empty?)
  end
end
