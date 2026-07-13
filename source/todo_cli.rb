# todo_cli.rb -- a small command-line task manager with JSON persistence.
#
# Demonstrates a professional CLI pattern in Spinel: a small hand-rolled flag
# parser, durable state via `json`, and File IO -- all ahead-of-time compiled
# to a single binary. Tasks are stored as an array of plain Hashes so they
# round-trip cleanly through JSON (string keys on load).
#
# Compile: SPINEL_REQUIRE_GATE=1 spinel source/todo_cli.rb -o bin/todo_cli
# Run:
#   ./bin/todo_cli add "write slides"     # append a task
#   ./bin/todo_cli list                    # show the table
#   ./bin/todo_cli done 1                  # mark task 1 complete
#   ./bin/todo_cli remove 1                # delete task 1
#   ./bin/todo_cli clear                   # drop all completed tasks
#   ./bin/todo_cli -f other.json list      # use a different data file
#
# The same file runs unmodified under CRuby (`ruby source/todo_cli.rb ...`),
# since json is real stdlib there and a require-gated package under Spinel.

require "json"

# Load the task list from disk. A missing file is treated as an empty list so
# the first `add` just works. JSON.parse yields Hashes with string keys.
def load_tasks(path)
  return [] unless File.exist?(path)
  data = File.read(path)
  return [] if data.nil? || data == ""
  JSON.parse(data)
end

# Persist the task list as pretty-printed JSON so the data file stays
# human-readable (and diff-friendly) between runs.
def save_tasks(path, tasks)
  File.write(path, JSON.pretty_generate(tasks))
end

# Compute the next id as one past the current maximum, so ids stay stable
# even after tasks in the middle are removed.
def next_id(tasks)
  max = 0
  tasks.each { |task| max = task["id"] if task["id"] > max }
  max + 1
end

# add "TITLE": append a new, incomplete task stamped with the current time.
# Time#strftime works directly in Spinel (no `require "time"` needed).
def cmd_add(path, tasks, title)
  if title.nil? || title == ""
    STDERR.puts "usage: todo_cli add \"TITLE\""
    exit 1
  end
  task = {
    "id" => next_id(tasks),
    "title" => title,
    "done" => false,
    "created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
  }
  tasks.push(task)
  save_tasks(path, tasks)
  puts "Added ##{task['id']}: #{title}"
end

# list: print an aligned table of id, done marker, and title.
def cmd_list(tasks)
  if tasks.empty?
    puts "No tasks yet. Add one with: todo_cli add \"...\""
    return
  end
  tasks.each do |task|
    marker = task["done"] ? "[x]" : "[ ]"
    id_col = task["id"].to_s.rjust(3)
    puts "#{id_col} #{marker} #{task['title']}"
  end
end

# Find a task by id, or print an error and exit 1 when it is unknown. Every
# id-taking command funnels through here so the failure behavior is uniform.
def find_task!(tasks, id_arg)
  id = id_arg.to_i
  task = nil
  tasks.each { |candidate| task = candidate if candidate["id"] == id }
  if task.nil?
    STDERR.puts "error: no task with id #{id_arg}"
    exit 1
  end
  task
end

# done ID: mark the task complete and save.
def cmd_done(path, tasks, id_arg)
  task = find_task!(tasks, id_arg)
  task["done"] = true
  save_tasks(path, tasks)
  puts "Completed ##{task['id']}: #{task['title']}"
end

# remove ID: delete the task and save. We rebuild the list with an explicit
# loop (rather than Array#delete or #reject) so the element type stays
# unambiguous for the compiler and the poly-array path stays supported.
def cmd_remove(path, tasks, id_arg)
  task = find_task!(tasks, id_arg)
  remaining = []
  tasks.each { |task_item| remaining.push(task_item) unless task_item["id"] == task["id"] }
  save_tasks(path, remaining)
  puts "Removed ##{task['id']}: #{task['title']}"
end

# clear: drop every completed task, keeping the open ones. Built with an
# explicit loop for the same poly-array reason as cmd_remove.
def cmd_clear(path, tasks)
  remaining = []
  tasks.each { |task_item| remaining.push(task_item) unless task_item["done"] }
  removed = tasks.length - remaining.length
  save_tasks(path, remaining)
  puts "Cleared #{removed} completed task(s)"
end

# --- entry point ---------------------------------------------------------

# The data file defaults to todo.json in the current directory. We parse the
# global flags with a small manual ARGV loop rather than OptionParser: Spinel's
# compiled-in optparse subset does not capture an option's VALUE (only boolean
# flags work), so `-f FILE` would silently no-op under the native binary. A
# hand-rolled loop behaves identically under both Spinel and CRuby, and we
# collect the remaining non-flag tokens as the command and its argument.
data_file = "todo.json"
positional = []
arg_index = 0
while arg_index < ARGV.length
  arg = ARGV[arg_index]
  if arg == "-f" || arg == "--file"
    file_value = ARGV[arg_index + 1]
    if file_value
      data_file = "#{file_value}"
      arg_index += 1
    end
  elsif arg == "-h" || arg == "--help"
    puts "Usage: todo_cli [options] COMMAND [args]"
    puts "  -f FILE   use FILE instead of todo.json"
    puts ""
    puts "Commands: add \"TITLE\" | list | done ID | remove ID | clear"
    exit 0
  else
    positional.push(arg)
  end
  arg_index += 1
end

command = positional[0]
tasks = load_tasks(data_file)

if command == "add"
  cmd_add(data_file, tasks, positional[1])
elsif command == "list"
  cmd_list(tasks)
elsif command == "done"
  cmd_done(data_file, tasks, positional[1])
elsif command == "remove"
  cmd_remove(data_file, tasks, positional[1])
elsif command == "clear"
  cmd_clear(data_file, tasks)
else
  STDERR.puts "usage: todo_cli [options] COMMAND [args]"
  STDERR.puts "commands: add, list, done, remove, clear (try -h)"
  exit 1
end
