from flask import Flask, request, redirect, render_template
import json
import os

app = Flask(__name__)
DATA_FILE = 'todos.json'

def read_todos():
    if not os.path.exists(DATA_FILE):
        return []
    with open(DATA_FILE, 'r') as f:
        return json.load(f)

def write_todos(todos):
    with open(DATA_FILE, 'w') as f:
        json.dump(todos, f, indent=2)

@app.route('/')
def index():
    todos = read_todos()
    return render_template('index.html', todos=todos)

@app.route('/add', methods=['POST'])
def add_todo():
    task = request.form.get('task')
    if task:
        todos = read_todos()
        new_todo = {'id': len(todos)+1, 'task': task}
        todos.append(new_todo)
        write_todos(todos)
    return redirect('/')

@app.route('/delete/<int:todo_id>')
def delete_todo(todo_id):
    todos = read_todos()
    todos = [t for t in todos if t['id'] != todo_id]
    write_todos(todos)
    return redirect('/')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
