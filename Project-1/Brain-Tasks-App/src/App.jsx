import React, { useState } from 'react'
import './App.css'

function App() {
  const [tasks, setTasks] = useState([
    { id: 1, text: 'Welcome to Brain Tasks App!', completed: false },
    { id: 2, text: 'Add your first task', completed: false },
    { id: 3, text: 'Deploy to AWS EKS', completed: false }
  ])
  const [newTask, setNewTask] = useState('')

  const addTask = () => {
    if (newTask.trim()) {
      setTasks([...tasks, { id: Date.now(), text: newTask, completed: false }])
      setNewTask('')
    }
  }

  const toggleTask = (id) => {
    setTasks(tasks.map(task => 
      task.id === id ? { ...task, completed: !task.completed } : task
    ))
  }

  const deleteTask = (id) => {
    setTasks(tasks.filter(task => task.id !== id))
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>🧠 Brain Tasks App</h1>
        <p>Manage your tasks efficiently</p>
      </header>
      
      <main className="app-main">
        <div className="task-input">
          <input
            type="text"
            value={newTask}
            onChange={(e) => setNewTask(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && addTask()}
            placeholder="Add a new task..."
          />
          <button onClick={addTask}>Add Task</button>
        </div>
        
        <div className="task-list">
          {tasks.map(task => (
            <div key={task.id} className={`task-item ${task.completed ? 'completed' : ''}`}>
              <input
                type="checkbox"
                checked={task.completed}
                onChange={() => toggleTask(task.id)}
              />
              <span className="task-text">{task.text}</span>
              <button onClick={() => deleteTask(task.id)} className="delete-btn">Delete</button>
            </div>
          ))}
        </div>
        
        <div className="task-stats">
          <p>Total tasks: {tasks.length}</p>
          <p>Completed: {tasks.filter(t => t.completed).length}</p>
          <p>Pending: {tasks.filter(t => !t.completed).length}</p>
        </div>
      </main>
    </div>
  )
}

export default App
